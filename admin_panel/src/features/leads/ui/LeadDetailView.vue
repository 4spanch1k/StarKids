<template>
  <template v-if="lead">
    <header class="lead-detail__header">
      <div class="lead-detail__copy">
        <div class="lead-detail__title-row">
          <h2>{{ lead.customerName }}</h2>
          <div class="lead-detail__badges">
            <StatusBadge :label="formatType(lead.type)" tone="neutral" />
            <StatusBadge
              :label="formatStatus(lead.status)"
              :tone="statusTone(lead.status)"
            />
          </div>
        </div>
        <p class="lead-detail__description">
          {{ lead.summary }}
        </p>
      </div>

      <div
        class="lead-detail__deadline"
        :class="deadlineClass(lead.type, lead.requestedDate)"
      >
        {{ deadlineLabel(lead.type, lead.requestedDate) }}
      </div>
    </header>

    <section class="lead-status-panel">
      <div class="admin-section-heading">
        <h3>Статус заявки</h3>
        <p>
          {{
            isStatusUpdating
              ? 'Сохраняем новый статус…'
              : 'Выберите следующий рабочий этап для этой заявки.'
          }}
        </p>
      </div>

      <div class="lead-status-panel__actions">
        <button
          v-for="status in leadStatuses"
          :key="status"
          type="button"
          class="lead-status-button"
          :class="{ 'lead-status-button--active': status === lead.status }"
          :disabled="isStatusUpdating || !isLeadStatusActionEnabled(lead.status, status)"
          @click="handleStatusAction(status)"
        >
          {{ formatStatus(status) }}
        </button>
      </div>

      <p class="lead-status-panel__hint">
        {{ describeLeadStatusFlow(lead.status) }}
      </p>

      <p
        v-if="statusSuccessMessage"
        class="admin-inline-message admin-inline-message--success"
      >
        {{ statusSuccessMessage }}
      </p>
      <p
        v-if="statusErrorMessage"
        class="admin-inline-message admin-inline-message--error"
      >
        {{ statusErrorMessage }}
      </p>
    </section>

    <section v-if="lead.type === 'birthday_request'" class="lead-sales-panel">
      <div class="admin-section-heading">
        <h3>Коммерческие данные</h3>
        <p>Это данные переговоров, а не факт оплаты или выручка.</p>
      </div>
      <div class="lead-sales-panel__fields">
        <label class="lead-sales-panel__field">
          <span>Ожидаемая стоимость, ₸</span>
          <input
            v-model.number="expectedAmountDraft"
            type="number"
            min="0"
            step="1"
            inputmode="numeric"
            placeholder="Не указана"
            :disabled="isStatusUpdating"
          />
        </label>
        <label class="lead-sales-panel__field">
          <span>Депозит, ₸</span>
          <input
            v-model.number="depositAmountDraft"
            type="number"
            min="0"
            step="1"
            inputmode="numeric"
            placeholder="Не указан"
            :disabled="isStatusUpdating"
          />
        </label>
        <label class="lead-sales-panel__field">
          <span>Получено, ₸</span>
          <input
            v-model.number="paidAmountDraft"
            type="number"
            min="0"
            step="1"
            inputmode="numeric"
            placeholder="Не указано"
            :disabled="isStatusUpdating"
          />
        </label>
        <label class="lead-sales-panel__field">
          <span>Причина потери</span>
          <select v-model="lostReasonDraft" :disabled="isStatusUpdating">
            <option value="">Не выбрана</option>
            <option v-for="option in lostReasonOptions" :key="option.value" :value="option.value">
              {{ option.label }}
            </option>
          </select>
        </label>
      </div>
      <p v-if="salesFormError" class="admin-inline-message admin-inline-message--error">
        {{ salesFormError }}
      </p>
      <button
        type="button"
        class="admin-button admin-button--secondary"
        :disabled="isStatusUpdating || !hasValidSalesAmounts()"
        @click="saveSalesFields"
      >
        Сохранить коммерческие данные
      </button>
    </section>

    <div class="admin-info-grid">
      <article class="lead-detail-card">
        <div class="admin-section-heading">
          <h3>Контакт</h3>
        </div>
        <dl class="lead-detail-card__list">
          <div>
            <dt>Телефон</dt>
            <dd>
              <a
                class="lead-detail-card__link"
                :href="formatTelHref(lead.phone)"
              >
                {{ lead.phone }}
              </a>
            </dd>
          </div>
          <div>
            <dt>Способ связи</dt>
            <dd>{{ formatContactMethod(lead.contactMethod) }}</dd>
          </div>
          <div v-if="lead.email">
            <dt>Email</dt>
            <dd>{{ lead.email }}</dd>
          </div>
          <div>
            <dt>Источник</dt>
            <dd>{{ formatSource(lead.source) }}</dd>
          </div>
        </dl>
      </article>

      <article class="lead-detail-card">
        <div class="admin-section-heading">
          <h3>{{ lead.type === 'contact' ? 'Параметры обращения' : 'Параметры заявки' }}</h3>
        </div>
        <dl class="lead-detail-card__list">
          <div>
            <dt>Тип</dt>
            <dd>{{ formatType(lead.type) }}</dd>
          </div>
          <div v-if="lead.type === 'birthday_request'">
            <dt>Филиал</dt>
            <dd>{{ formatBranchName(lead.branch) }}</dd>
          </div>
          <div v-if="lead.type === 'birthday_request'">
            <dt>Пакет</dt>
            <dd>{{ formatPackageName(lead.package) }}</dd>
          </div>
          <div v-if="lead.type === 'birthday_request' && lead.childName">
            <dt>Ребёнок</dt>
            <dd>
              {{ lead.childName }}<span v-if="lead.childBirthDate">, {{ formatDate(lead.childBirthDate) }}</span>
            </dd>
          </div>
          <div v-if="lead.type === 'birthday_request' && lead.packagePriceSnapshot !== null && lead.packagePriceSnapshot !== undefined">
            <dt>Цена на момент заявки</dt>
            <dd>{{ formatMoney(lead.packagePriceSnapshot) }}</dd>
          </div>
          <div v-if="lead.type === 'birthday_request' && lead.agreedAmountTenge !== null && lead.agreedAmountTenge !== undefined">
            <dt>Согласованная стоимость</dt>
            <dd>{{ formatMoney(lead.agreedAmountTenge) }}</dd>
          </div>
          <div v-if="lead.type === 'birthday_request' && lead.depositAmountTenge !== null && lead.depositAmountTenge !== undefined">
            <dt>Депозит</dt>
            <dd>{{ formatMoney(lead.depositAmountTenge) }}</dd>
          </div>
          <div v-if="lead.type === 'birthday_request' && lead.paidAmountTenge !== null && lead.paidAmountTenge !== undefined">
            <dt>Оплачено</dt>
            <dd>{{ formatMoney(lead.paidAmountTenge) }}</dd>
          </div>
          <div v-if="lead.type === 'birthday_request' && lead.status === 'lost'">
            <dt>Причина потери</dt>
            <dd>{{ formatLostReason(lead.lostReason) }}</dd>
          </div>
          <div v-if="lead.type === 'birthday_request'">
            <dt>Гостей</dt>
            <dd>{{ formatGuestCount(lead.guestCount) }}</dd>
          </div>
          <div v-if="lead.type === 'birthday_request'">
            <dt>Дата праздника</dt>
            <dd>{{ formatDate(lead.requestedDate) }}</dd>
          </div>
          <div>
            <dt>Создана</dt>
            <dd>{{ formatDateTime(lead.createdAt) }}</dd>
          </div>
          <template v-if="lead.type === 'birthday_request'">
            <div>
              <dt>Первый контакт</dt>
              <dd>{{ lead.contactedAt ? formatDateTime(lead.contactedAt) : 'Ещё не было' }}</dd>
            </div>
            <div v-if="lead.waitingForContactMinutes !== null">
              <dt>Ожидает контакта</dt>
              <dd>{{ formatDuration(lead.waitingForContactMinutes) }}</dd>
            </div>
            <div v-if="lead.firstContactMinutes !== null">
              <dt>Время до контакта</dt>
              <dd>{{ formatDuration(lead.firstContactMinutes) }}</dd>
            </div>
          </template>
          <div v-if="lead.contactedAt">
            <dt>Связались</dt>
            <dd>{{ formatDateTime(lead.contactedAt) }}</dd>
          </div>
          <div v-if="lead.qualifiedAt">
            <dt>Квалифицирована</dt>
            <dd>{{ formatDateTime(lead.qualifiedAt) }}</dd>
          </div>
          <div v-if="lead.bookedAt">
            <dt>Забронировано</dt>
            <dd>{{ formatDateTime(lead.bookedAt) }}</dd>
          </div>
          <div v-if="lead.paidAt">
            <dt>Оплачено</dt>
            <dd>{{ formatDateTime(lead.paidAt) }}</dd>
          </div>
          <div v-if="lead.completedAt">
            <dt>Проведено</dt>
            <dd>{{ formatDateTime(lead.completedAt) }}</dd>
          </div>
          <div v-if="lead.lostAt">
            <dt>Потеряно</dt>
            <dd>{{ formatDateTime(lead.lostAt) }}</dd>
          </div>
        </dl>
      </article>

      <article class="lead-detail-card lead-detail-card--full">
        <div class="admin-section-heading">
          <h3>{{ lead.type === 'contact' ? 'Контекст обращения' : 'Комментарий клиента' }}</h3>
        </div>
        <p class="lead-detail-card__notes">
          {{ notesFallback(lead.type, lead.notes) }}
        </p>
      </article>

      <article v-if="lead.type === 'birthday_request'" class="lead-detail-card lead-detail-card--full">
        <div class="admin-section-heading">
          <h3>Внутренняя заметка</h3>
          <p>Видна только менеджерам.</p>
        </div>
        <textarea
          v-model="adminNoteDraft"
          class="lead-detail-card__note-input"
          maxlength="2000"
          rows="4"
          placeholder="Например: позвонили, ждём подтверждение даты."
          :disabled="isStatusUpdating"
        />
        <button
          type="button"
          class="admin-button admin-button--secondary lead-detail-card__note-button"
          :disabled="isStatusUpdating"
          @click="emit('save-note', adminNoteDraft.trim())"
        >
          Сохранить заметку
        </button>
      </article>
    </div>
  </template>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import {
  describeLeadStatusFlow,
  formatLeadStatus as formatStatus,
  formatLeadType as formatType,
  isLeadStatusActionEnabled,
  leadStatuses,
  lostReasonOptions,
  type LeadBranchSummary,
  type LeadDetail,
  type LeadPackageSummary,
  type LeadStatus,
  type LeadStatusUpdate,
  type LeadType,
} from '@/entities/lead/model/lead';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const props = defineProps<{
  lead: LeadDetail;
  isStatusUpdating: boolean;
  statusSuccessMessage: string;
  statusErrorMessage: string;
}>();

const emit = defineEmits<{
  'update-status': [update: LeadStatus | LeadStatusUpdate];
  'save-note': [note: string];
}>();

const adminNoteDraft = ref(props.lead.adminNote ?? '');
const expectedAmountDraft = ref<number | string | null>(props.lead.expectedAmountTenge ?? props.lead.agreedAmountTenge ?? null);
const depositAmountDraft = ref<number | string | null>(props.lead.depositAmountTenge ?? null);
const paidAmountDraft = ref<number | string | null>(props.lead.paidAmountTenge ?? null);
const lostReasonDraft = ref(props.lead.lostReason ?? '');
const salesFormError = ref('');

watch(
  () => [props.lead.id, props.lead.expectedAmountTenge, props.lead.agreedAmountTenge, props.lead.depositAmountTenge, props.lead.paidAmountTenge, props.lead.lostReason],
  () => {
    adminNoteDraft.value = props.lead.adminNote ?? '';
    expectedAmountDraft.value = props.lead.expectedAmountTenge ?? props.lead.agreedAmountTenge ?? null;
    depositAmountDraft.value = props.lead.depositAmountTenge ?? null;
    paidAmountDraft.value = props.lead.paidAmountTenge ?? null;
    lostReasonDraft.value = props.lead.lostReason ?? '';
    salesFormError.value = '';
  },
);

function handleStatusAction(status: LeadStatus) {
  salesFormError.value = '';
  if (status === 'lost' && !lostReasonDraft.value) {
    salesFormError.value = 'Перед переводом в «Не состоялось» выберите причину потери.';
    return;
  }
  if (status === 'paid' && normalizedAmount(paidAmountDraft.value) === undefined) {
    salesFormError.value = 'Перед переводом в «Оплачено» укажите полученную сумму.';
    return;
  }

  emit('update-status', {
    status,
    expectedAmountTenge: normalizedAmount(expectedAmountDraft.value),
    depositAmountTenge: normalizedAmount(depositAmountDraft.value),
    paidAmountTenge: normalizedAmount(paidAmountDraft.value),
    lostReason: status === 'lost' ? lostReasonDraft.value : undefined,
  });
}

function saveSalesFields() {
  salesFormError.value = '';
  if (!hasValidSalesAmounts()) {
    salesFormError.value = 'Укажите суммы целыми неотрицательными числами.';
    return;
  }

  emit('update-status', {
    status: props.lead.status,
    expectedAmountTenge: normalizedAmount(expectedAmountDraft.value),
    depositAmountTenge: normalizedAmount(depositAmountDraft.value),
    paidAmountTenge: normalizedAmount(paidAmountDraft.value),
    lostReason: props.lead.status === 'lost' ? lostReasonDraft.value || undefined : undefined,
  });
}

function normalizedAmount(value: number | string | null): number | undefined {
  if (value === null || value === '') {
    return undefined;
  }

  const amount = Number(value);
  return Number.isInteger(amount) && amount >= 0 ? amount : undefined;
}

function hasValidSalesAmounts(): boolean {
  return [expectedAmountDraft.value, depositAmountDraft.value, paidAmountDraft.value].every((value) => {
    if (value === null || value === '') {
      return true;
    }
    const amount = Number(value);
    return Number.isInteger(amount) && amount >= 0;
  });
}

function statusTone(status: LeadStatus): 'new' | 'in-progress' | 'closed' {
  if (status === 'new') {
    return 'new';
  }

  if (
    status === 'in_progress' ||
    status === 'contacted' ||
    status === 'qualified' ||
    status === 'booked' ||
    status === 'paid'
  ) {
    return 'in-progress';
  }

  return 'closed';
}

function formatDate(value: string | null): string {
  if (!value) {
    return 'Не указана';
  }

  return new Intl.DateTimeFormat('ru-RU', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(new Date(`${value}T00:00:00`));
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('ru-RU', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function formatDuration(minutes: number | null): string {
  if (minutes === null) {
    return 'Неизвестно';
  }

  if (minutes < 60) {
    return `${minutes} мин`;
  }

  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  if (hours < 24) {
    return remainingMinutes ? `${hours} ч ${remainingMinutes} мин` : `${hours} ч`;
  }

  const days = Math.floor(hours / 24);
  const remainingHours = hours % 24;
  return remainingHours ? `${days} д ${remainingHours} ч` : `${days} д`;
}

function formatGuestCount(value: number | null): string {
  if (!value) {
    return 'Не указано';
  }

  if (value === 1) {
    return '1 гость';
  }

  return `${value} гостей`;
}

function formatMoney(value: number): string {
  return new Intl.NumberFormat('ru-RU').format(value) + ' ₸';
}

function formatLostReason(value: string | null | undefined): string {
  return lostReasonOptions.find((option) => option.value === value)?.label ?? 'Не указана';
}

function formatContactMethod(value: string): string {
  const labels: Record<string, string> = {
    phone: 'Телефон',
    whatsapp: 'WhatsApp',
  };

  return labels[value] ?? value;
}

function formatSource(value: string): string {
  const labels: Record<string, string> = {
    mobile_app: 'Мобильное приложение',
  };

  return labels[value] ?? value;
}

function formatTelHref(phone: string): string {
  return `tel:${phone.replace(/[^\d+]/g, '')}`;
}

function formatBranchName(branch: LeadBranchSummary | null): string {
  if (!branch) {
    return 'Не выбран';
  }

  return branch.shortLabel || branch.name;
}

function formatPackageName(birthdayPackage: LeadPackageSummary | null): string {
  return birthdayPackage?.name ?? 'Не выбран';
}

function notesFallback(type: LeadType, notes: string | null): string {
  if (notes) {
    return notes;
  }

  return type === 'contact'
    ? 'Клиент не оставил текст обращения.'
    : 'Комментарий не оставлен.';
}

function deadlineLabel(type: LeadType, value: string | null): string {
  if (type === 'contact') {
    return 'Контактное обращение';
  }

  if (!value) {
    return 'Дата праздника не указана';
  }

  return `Праздник ${formatDate(value)}`;
}

function deadlineTone(type: LeadType, value: string | null): 'neutral' | 'warning' | 'danger' {
  if (type === 'contact') {
    return 'neutral';
  }

  if (!value) {
    return 'neutral';
  }

  const today = startOfDay(new Date());
  const requestedDate = startOfDay(new Date(`${value}T00:00:00`));
  const diffInDays = Math.round((requestedDate.getTime() - today.getTime()) / 86400000);

  if (diffInDays < 0 || diffInDays <= 1) {
    return 'danger';
  }

  if (diffInDays <= 3) {
    return 'warning';
  }

  return 'neutral';
}

function deadlineClass(type: LeadType, value: string | null): string {
  return `lead-deadline--${deadlineTone(type, value)}`;
}

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}
</script>

<style scoped>
.lead-detail__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}

.lead-detail__copy {
  display: grid;
  gap: 6px;
}

.lead-detail__title-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
}

.lead-detail__title-row h2,
.lead-status-panel h3 {
  margin: 0;
}

.lead-detail__title-row h2 {
  font-size: 20px;
  line-height: 1.15;
}

.lead-detail__badges {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
}

.lead-detail__description,
.lead-status-panel__hint,
.lead-detail-card__notes {
  margin: 0;
  line-height: 1.4;
}

.lead-detail__description,
.lead-status-panel__hint {
  color: var(--color-muted);
}

.lead-sales-panel {
  display: grid;
  gap: 12px;
  margin-top: 14px;
  padding: 14px;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-surface-subtle);
}

.lead-sales-panel__fields {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.lead-sales-panel__field {
  display: grid;
  gap: 6px;
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 700;
}

.lead-sales-panel__field input,
.lead-sales-panel__field select {
  min-height: 38px;
  padding: 0 10px;
  border: 1px solid var(--color-border);
  border-radius: 10px;
  background: var(--color-surface);
  color: var(--color-text);
  font: inherit;
}

.lead-detail__deadline {
  display: inline-flex;
  align-items: center;
  min-height: 30px;
  padding: 0 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
  white-space: nowrap;
}

.lead-deadline--neutral {
  background: var(--color-surface-subtle);
  color: var(--color-text);
}

.lead-deadline--warning {
  background: var(--color-warning-soft);
  color: var(--color-warning);
}

.lead-deadline--danger {
  background: var(--color-danger-soft);
  color: var(--color-danger);
}

.lead-status-panel {
  display: grid;
  gap: 8px;
  padding-block: 2px;
}

.lead-status-panel__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.lead-status-button {
  min-height: 32px;
  padding: 0 10px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  color: var(--color-text);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition:
    border-color 120ms ease,
    background-color 120ms ease,
    color 120ms ease;
}

.lead-status-button:hover:not(:disabled),
.lead-status-button--active {
  border-color: rgba(208, 47, 112, 0.24);
  background: #fff3f8;
  color: var(--color-accent);
}

.lead-status-button:disabled {
  cursor: wait;
  opacity: 0.65;
}

.lead-detail-card {
  display: grid;
  gap: 8px;
  padding: 12px;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-surface-subtle);
}

.lead-detail-card--full {
  grid-column: 1 / -1;
}

.lead-detail-card__list {
  display: grid;
  gap: 8px;
  margin: 0;
}

.lead-detail-card__list dt {
  margin-bottom: 2px;
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 600;
}

.lead-detail-card__list dd {
  margin: 0;
  font-size: 13px;
  line-height: 1.35;
}

.lead-detail-card__link {
  color: var(--color-text);
  font-size: 13px;
  font-weight: 600;
}

.lead-detail-card__link:hover {
  color: var(--color-accent);
}

.lead-detail-card__note-input {
  width: 100%;
  min-height: 92px;
  padding: 10px 12px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  color: var(--color-text);
  font: inherit;
  line-height: 1.4;
  resize: vertical;
}

.lead-detail-card__note-button {
  justify-self: start;
}

.admin-info-grid {
  gap: 10px;
}

@media (max-width: 900px) {
  .lead-detail__header {
    flex-direction: column;
    align-items: flex-start;
  }

  .lead-sales-panel__fields {
    grid-template-columns: 1fr;
  }
}
</style>
