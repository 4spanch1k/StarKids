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
          @click="$emit('update-status', status)"
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
    </div>
  </template>
</template>

<script setup lang="ts">
import {
  describeLeadStatusFlow,
  formatLeadStatus as formatStatus,
  formatLeadType as formatType,
  isLeadStatusActionEnabled,
  leadStatuses,
  type LeadBranchSummary,
  type LeadDetail,
  type LeadPackageSummary,
  type LeadStatus,
  type LeadType,
} from '@/entities/lead/model/lead';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

defineProps<{
  lead: LeadDetail;
  isStatusUpdating: boolean;
  statusSuccessMessage: string;
  statusErrorMessage: string;
}>();

defineEmits<{
  'update-status': [status: LeadStatus];
}>();

function statusTone(status: LeadStatus): 'new' | 'in-progress' | 'closed' {
  if (status === 'new') {
    return 'new';
  }

  if (status === 'in_progress') {
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

function formatGuestCount(value: number | null): string {
  if (!value) {
    return 'Не указано';
  }

  if (value === 1) {
    return '1 гость';
  }

  return `${value} гостей`;
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
  gap: 12px;
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
  line-height: 1.45;
}

.lead-detail__description,
.lead-status-panel__hint {
  color: var(--color-muted);
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
  gap: 10px;
}

.lead-status-panel__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.lead-status-button {
  min-height: 36px;
  padding: 0 12px;
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
  gap: 10px;
  padding: 14px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface-subtle);
}

.lead-detail-card--full {
  grid-column: 1 / -1;
}

.lead-detail-card__list {
  display: grid;
  gap: 10px;
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
  font-size: 14px;
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

@media (max-width: 900px) {
  .lead-detail__header {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
