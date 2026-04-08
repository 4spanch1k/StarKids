<template>
  <PageShell
    eyebrow="Операционный контур"
    title="Заявки"
    description="Очередь входящих обращений, рабочие статусы и детали клиента на одном экране."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--secondary"
        :disabled="leadInbox.isListLoading"
        @click="leadInbox.loadLeads"
      >
        {{ leadInbox.isListLoading ? 'Обновляем…' : 'Обновить список' }}
      </button>
    </template>

    <section class="admin-panel admin-panel--stack">
      <form class="lead-filters" @submit.prevent="leadInbox.loadLeads">
        <AppSelectField
          v-model="leadInbox.filters.branchId"
          label="Филиал"
          :options="branchFilterOptions"
          :disabled="leadInbox.isListLoading || leadInbox.isBranchesLoading"
        />

        <AppSelectField
          v-model="leadInbox.filters.status"
          label="Статус"
          :options="statusFilterOptions"
          :disabled="leadInbox.isListLoading"
        />

        <AppDateRangeField
          v-model="createdRange"
          label="Период"
          :disabled="leadInbox.isListLoading"
        />

        <div class="lead-filters__actions admin-form-actions">
          <button
            type="submit"
            class="admin-button admin-button--primary"
            :disabled="leadInbox.isListLoading"
          >
            {{ leadInbox.isListLoading ? 'Применяем…' : 'Применить' }}
          </button>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            :disabled="leadInbox.isListLoading || !leadInbox.hasActiveFilters"
            @click="leadInbox.resetFilters"
          >
            Сбросить
          </button>
        </div>
      </form>

      <p
        v-if="leadInbox.branchesErrorMessage"
        class="admin-inline-message admin-inline-message--error"
      >
        {{ leadInbox.branchesErrorMessage }}
      </p>

      <div class="leads-toolbar">
        <div class="leads-toolbar__summary">
          <p class="leads-toolbar__title">{{ totalLabel }}</p>
          <p class="leads-toolbar__hint">{{ filterSummary }}</p>
        </div>

        <div class="leads-toolbar__badges">
          <StatusBadge :label="`Новые: ${newLeadCount}`" tone="new" />
          <StatusBadge :label="`В работе: ${inProgressLeadCount}`" tone="in-progress" />
          <StatusBadge
            :label="`Срочно: ${urgentLeadCount}`"
            :tone="urgentLeadCount ? 'danger' : 'neutral'"
          />
        </div>
      </div>
    </section>

    <div class="admin-split-layout">
      <section class="admin-panel admin-panel--stack lead-queue">
        <div class="admin-section-heading">
          <h2>Очередь заявок</h2>
          <p>Выберите обращение слева. Детали и действия откроются справа без дополнительных переходов.</p>
        </div>

        <StatePanel
          v-if="leadInbox.isListLoading"
          title="Загружаем заявки"
          description="Подождите пару секунд, обновляем очередь с сервера."
        />

        <StatePanel
          v-else-if="leadInbox.listErrorMessage"
          title="Не удалось открыть список заявок"
          :description="leadInbox.listErrorMessage"
          tone="error"
        >
          <template #actions>
            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="leadInbox.loadLeads"
            >
              Повторить
            </button>
          </template>
        </StatePanel>

        <StatePanel
          v-else-if="leadInbox.leads.length === 0"
          title="По этим фильтрам заявок нет"
          description="Измените период, филиал или статус, чтобы вернуть обращения в очередь."
        >
          <template #actions>
            <button
              type="button"
              class="admin-button admin-button--primary"
              :disabled="!leadInbox.hasActiveFilters"
              @click="leadInbox.resetFilters"
            >
              Сбросить фильтры
            </button>
          </template>
        </StatePanel>

        <div v-else class="admin-list-stack lead-queue__list">
          <article
            v-for="lead in leadInbox.leads"
            :key="lead.id"
            class="lead-card"
            :class="{ 'lead-card--active': lead.id === leadInbox.selectedLeadId }"
          >
            <button
              type="button"
              class="lead-card__main"
              @click="leadInbox.selectLead(lead.id)"
            >
              <div class="lead-card__header">
                <div class="lead-card__title">
                  <strong>{{ lead.customerName }}</strong>
                  <p>
                    {{ lead.branch.shortLabel }}
                    <span v-if="lead.package"> · {{ lead.package.name }}</span>
                  </p>
                </div>
                <StatusBadge
                  :label="formatStatus(lead.status)"
                  :tone="statusTone(lead.status)"
                />
              </div>

              <div class="lead-card__timeline">
                <div
                  class="lead-card__deadline"
                  :class="deadlineClass(lead.requestedDate)"
                >
                  {{ deadlineLabel(lead.requestedDate) }}
                </div>
                <p class="lead-card__created">Создана {{ formatDateTime(lead.createdAt) }}</p>
              </div>

              <dl class="lead-card__facts">
                <div>
                  <dt>Телефон</dt>
                  <dd>{{ lead.phone }}</dd>
                </div>
                <div>
                  <dt>Гостей</dt>
                  <dd>{{ formatGuestCount(lead.guestCount) }}</dd>
                </div>
              </dl>
            </button>

            <div class="lead-card__actions">
              <a
                class="lead-card__contact"
                :href="formatTelHref(lead.phone)"
                @click.stop
              >
                Позвонить
              </a>

              <div class="lead-card__quick-actions">
                <button
                  v-if="lead.status === 'new'"
                  type="button"
                  class="admin-button admin-button--secondary lead-card__quick-button"
                  :disabled="leadInbox.isStatusUpdating"
                  @click.stop="leadInbox.quickUpdateLeadStatus(lead.id, 'in_progress')"
                >
                  В работу
                </button>
                <button
                  v-else-if="lead.status === 'in_progress'"
                  type="button"
                  class="admin-button admin-button--secondary lead-card__quick-button"
                  :disabled="leadInbox.isStatusUpdating"
                  @click.stop="leadInbox.quickUpdateLeadStatus(lead.id, 'closed')"
                >
                  Закрыть
                </button>
              </div>
            </div>
          </article>
        </div>
      </section>

      <aside class="admin-panel admin-panel--stack lead-detail">
        <template v-if="!leadInbox.selectedLeadId">
          <StatePanel
            title="Выберите заявку слева"
            description="Детали клиента, комментарий и управление статусом появятся здесь."
          />
        </template>

        <template v-else-if="leadInbox.isDetailLoading && !leadInbox.selectedLead">
          <StatePanel
            title="Загружаем детали заявки"
            description="Собираем контакты, пакет и комментарий по выбранному обращению."
          />
        </template>

        <template v-else-if="leadInbox.detailErrorMessage">
          <StatePanel
            title="Не удалось открыть заявку"
            :description="leadInbox.detailErrorMessage"
            tone="error"
          >
            <template #actions>
              <button
                type="button"
                class="admin-button admin-button--secondary"
                @click="leadInbox.selectLead(leadInbox.selectedLeadId)"
              >
                Повторить
              </button>
            </template>
          </StatePanel>
        </template>

        <template v-else-if="leadInbox.selectedLead">
          <header class="lead-detail__header">
            <div class="lead-detail__copy">
              <p class="lead-detail__eyebrow">Выбранная заявка</p>
              <div class="lead-detail__title-row">
                <h2>{{ leadInbox.selectedLead.customerName }}</h2>
                <StatusBadge
                  :label="formatStatus(leadInbox.selectedLead.status)"
                  :tone="statusTone(leadInbox.selectedLead.status)"
                />
              </div>
              <p class="lead-detail__description">
                {{ leadInbox.selectedLead.branch.name }}
                <span v-if="leadInbox.selectedLead.package">
                  · {{ leadInbox.selectedLead.package.name }}
                </span>
              </p>
            </div>

            <div
              class="lead-detail__deadline"
              :class="deadlineClass(leadInbox.selectedLead.requestedDate)"
            >
              {{ deadlineLabel(leadInbox.selectedLead.requestedDate) }}
            </div>
          </header>

          <section class="lead-status-panel">
            <div class="admin-section-heading">
              <h3>Статус заявки</h3>
              <p>
                {{
                  leadInbox.isStatusUpdating
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
                :class="{
                  'lead-status-button--active': status === leadInbox.selectedLead.status,
                }"
                :disabled="leadInbox.isStatusUpdating"
                @click="leadInbox.updateLeadStatus(status)"
              >
                {{ formatStatus(status) }}
              </button>
            </div>

            <p
              v-if="leadInbox.statusSuccessMessage"
              class="admin-inline-message admin-inline-message--success"
            >
              {{ leadInbox.statusSuccessMessage }}
            </p>
            <p
              v-if="leadInbox.statusErrorMessage"
              class="admin-inline-message admin-inline-message--error"
            >
              {{ leadInbox.statusErrorMessage }}
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
                      :href="formatTelHref(leadInbox.selectedLead.phone)"
                    >
                      {{ leadInbox.selectedLead.phone }}
                    </a>
                  </dd>
                </div>
                <div>
                  <dt>Способ связи</dt>
                  <dd>{{ formatContactMethod(leadInbox.selectedLead.contactMethod) }}</dd>
                </div>
                <div>
                  <dt>Источник</dt>
                  <dd>{{ formatSource(leadInbox.selectedLead.source) }}</dd>
                </div>
              </dl>
            </article>

            <article class="lead-detail-card">
              <div class="admin-section-heading">
                <h3>Параметры заявки</h3>
              </div>
              <dl class="lead-detail-card__list">
                <div>
                  <dt>Гостей</dt>
                  <dd>{{ formatGuestCount(leadInbox.selectedLead.guestCount) }}</dd>
                </div>
                <div>
                  <dt>Дата праздника</dt>
                  <dd>{{ formatDate(leadInbox.selectedLead.requestedDate) }}</dd>
                </div>
                <div>
                  <dt>Создана</dt>
                  <dd>{{ formatDateTime(leadInbox.selectedLead.createdAt) }}</dd>
                </div>
              </dl>
            </article>

            <article class="lead-detail-card lead-detail-card--full">
              <div class="admin-section-heading">
                <h3>Комментарий клиента</h3>
              </div>
              <p class="lead-detail-card__notes">
                {{ leadInbox.selectedLead.notes || 'Комментарий не оставлен.' }}
              </p>
            </article>
          </div>
        </template>
      </aside>
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive } from 'vue';

import { leadStatuses, type LeadStatus } from '@/entities/lead/model/lead';
import { useLeadInbox } from '@/features/leads/model/useLeadInbox';
import AppDateRangeField from '@/shared/ui/AppDateRangeField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const leadInbox = reactive(useLeadInbox());

const statusLabels: Record<LeadStatus, string> = {
  new: 'Новая',
  in_progress: 'В работе',
  closed: 'Закрыта',
};

const totalLabel = computed(() => {
  const count = leadInbox.total;
  if (count === 0) {
    return 'Сейчас заявок нет';
  }
  if (count === 1) {
    return '1 заявка в очереди';
  }
  return `${count} заявок в очереди`;
});

const filterSummary = computed(() => {
  if (!leadInbox.hasActiveFilters) {
    return 'Показаны все обращения без дополнительных ограничений.';
  }

  return 'Очередь отфильтрована по выбранным условиям.';
});

const newLeadCount = computed(() => {
  return leadInbox.leads.filter((lead) => lead.status === 'new').length;
});

const inProgressLeadCount = computed(() => {
  return leadInbox.leads.filter((lead) => lead.status === 'in_progress').length;
});

const urgentLeadCount = computed(() => {
  return leadInbox.leads.filter((lead) => deadlineTone(lead.requestedDate) === 'danger').length;
});

const branchFilterOptions = computed(() => {
  return [
    { label: 'Все филиалы', value: '' },
    ...leadInbox.branchOptions.map((branch) => ({
      label: branch.shortLabel,
      value: branch.id,
    })),
  ];
});

const statusFilterOptions = computed(() => {
  return [
    { label: 'Все статусы', value: '' },
    ...leadStatuses.map((status) => ({
      label: formatStatus(status),
      value: status,
    })),
  ];
});

const createdRange = computed({
  get() {
    return {
      from: leadInbox.filters.createdFrom,
      to: leadInbox.filters.createdTo,
    };
  },
  set(value: { from: string; to: string }) {
    leadInbox.filters.createdFrom = value.from;
    leadInbox.filters.createdTo = value.to;
  },
});

onMounted(() => {
  void leadInbox.initialize();
});

function formatStatus(status: LeadStatus): string {
  return statusLabels[status];
}

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

function deadlineLabel(value: string | null): string {
  if (!value) {
    return 'Дата праздника не указана';
  }

  return `Праздник ${formatDate(value)}`;
}

function deadlineTone(value: string | null): 'neutral' | 'warning' | 'danger' {
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

function deadlineClass(value: string | null): string {
  return `lead-deadline--${deadlineTone(value)}`;
}

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

</script>

<style scoped>
.lead-filters {
  display: grid;
  grid-template-columns: 170px 170px minmax(280px, 1fr) auto;
  gap: 8px;
  align-items: end;
}

.lead-filters__actions {
  justify-content: flex-end;
}

.leads-toolbar {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.leads-toolbar__summary {
  min-width: 0;
}

.leads-toolbar__title,
.leads-toolbar__hint {
  margin: 0;
}

.leads-toolbar__title {
  font-size: 15px;
  font-weight: 700;
}

.leads-toolbar__hint {
  margin-top: 3px;
  color: var(--color-muted);
  line-height: 1.45;
}

.leads-toolbar__badges {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 6px;
}

.lead-queue {
  min-height: 0;
}

.lead-queue__list {
  max-height: calc(100vh - 290px);
  overflow-y: auto;
  padding-right: 2px;
}

.lead-card {
  display: grid;
  gap: 8px;
  padding: 12px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  transition:
    border-color 120ms ease,
    box-shadow 120ms ease,
    background-color 120ms ease;
}

.lead-card:hover,
.lead-card--active {
  border-color: rgba(208, 47, 112, 0.24);
  background: #fffafd;
  box-shadow: 0 8px 20px rgba(208, 47, 112, 0.08);
}

.lead-card__main {
  display: grid;
  gap: 8px;
  padding: 0;
  border: 0;
  background: transparent;
  text-align: left;
  cursor: pointer;
}

.lead-card__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}

.lead-card__title {
  display: grid;
  gap: 2px;
}

.lead-card__title strong {
  font-size: 16px;
  line-height: 1.2;
}

.lead-card__title p,
.lead-card__created {
  margin: 0;
  color: var(--color-muted);
  font-size: 13px;
  line-height: 1.35;
}

.lead-card__timeline {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.lead-card__deadline,
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

.lead-card__facts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 6px 10px;
  margin: 0;
}

.lead-card__facts dt,
.lead-detail-card__list dt {
  margin-bottom: 2px;
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 600;
}

.lead-card__facts dd,
.lead-detail-card__list dd {
  margin: 0;
  font-size: 14px;
  line-height: 1.35;
}

.lead-card__actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding-top: 6px;
  border-top: 1px solid var(--color-border);
}

.lead-card__contact,
.lead-detail-card__link {
  color: var(--color-text);
  font-size: 13px;
  font-weight: 600;
}

.lead-card__contact:hover,
.lead-detail-card__link:hover {
  color: var(--color-accent);
}

.lead-card__quick-actions {
  display: flex;
  justify-content: flex-end;
  gap: 6px;
}

.lead-card__quick-button {
  min-height: 32px;
  padding-inline: 9px;
  font-size: 12px;
}

.lead-detail {
  position: sticky;
  top: 18px;
}

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

.lead-detail__eyebrow {
  margin: 0;
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
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

.lead-detail__description {
  margin: 0;
  color: var(--color-muted);
  line-height: 1.45;
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

.lead-detail-card__notes {
  margin: 0;
  color: var(--color-text);
  line-height: 1.55;
}

@media (max-width: 1280px) {
  .lead-filters {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 900px) {
  .lead-card__timeline,
  .lead-card__actions,
  .lead-detail__header,
  .leads-toolbar {
    flex-direction: column;
    align-items: flex-start;
  }

  .lead-card__facts {
    grid-template-columns: 1fr;
  }

  .lead-detail {
    position: static;
  }
}

@media (max-width: 720px) {
  .lead-filters {
    grid-template-columns: 1fr;
  }

  .lead-filters__actions,
  .leads-toolbar__badges,
  .lead-card__quick-actions {
    width: 100%;
    justify-content: flex-start;
  }
}
</style>
