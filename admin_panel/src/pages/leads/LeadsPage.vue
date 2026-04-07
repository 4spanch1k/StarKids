<template>
  <PageShell
    eyebrow="Операционный контур"
    title="Заявки"
    description="Один рабочий экран для просмотра входящих обращений, уточнения деталей и смены статуса без лишних переходов."
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
      <form class="admin-form-grid" @submit.prevent="leadInbox.loadLeads">
        <label class="admin-field">
          <span class="admin-field__label">Филиал</span>
          <select
            v-model="leadInbox.filters.branchId"
            class="admin-control"
            :disabled="leadInbox.isListLoading || leadInbox.isBranchesLoading"
          >
            <option value="">Все филиалы</option>
            <option
              v-for="branch in leadInbox.branchOptions"
              :key="branch.id"
              :value="branch.id"
            >
              {{ branch.shortLabel }}
            </option>
          </select>
        </label>

        <label class="admin-field">
          <span class="admin-field__label">Статус</span>
          <select
            v-model="leadInbox.filters.status"
            class="admin-control"
            :disabled="leadInbox.isListLoading"
          >
            <option value="">Все статусы</option>
            <option v-for="status in leadStatuses" :key="status" :value="status">
              {{ formatStatus(status) }}
            </option>
          </select>
        </label>

        <label class="admin-field">
          <span class="admin-field__label">С даты</span>
          <input
            v-model="leadInbox.filters.createdFrom"
            class="admin-control"
            type="date"
            :disabled="leadInbox.isListLoading"
          />
        </label>

        <label class="admin-field">
          <span class="admin-field__label">По дату</span>
          <input
            v-model="leadInbox.filters.createdTo"
            class="admin-control"
            type="date"
            :disabled="leadInbox.isListLoading"
          />
        </label>

        <div class="admin-form-actions">
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

      <div class="leads-meta">
        <div>
          <p class="leads-meta__title">{{ totalLabel }}</p>
          <p class="leads-meta__hint">{{ filterSummary }}</p>
        </div>
        <StatusBadge :label="statusSummaryLabel" tone="neutral" />
      </div>
    </section>

    <div class="admin-split-layout">
      <section class="admin-panel admin-panel--stack">
        <div class="admin-section-heading">
          <h2>Список заявок</h2>
          <p>Слева — очередь обращений. Выберите нужную заявку, чтобы увидеть детали и сменить статус.</p>
        </div>

        <StatePanel
          v-if="leadInbox.isListLoading"
          title="Загружаем заявки"
          description="Подождите пару секунд, обновляем список с сервера."
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
          description="Измените период, филиал или статус — и список появится здесь."
        >
          <template #actions>
            <button
              type="button"
              class="admin-button admin-button--secondary"
              :disabled="!leadInbox.hasActiveFilters"
              @click="leadInbox.resetFilters"
            >
              Сбросить фильтры
            </button>
          </template>
        </StatePanel>

        <div v-else class="admin-list-stack">
          <button
            v-for="lead in leadInbox.leads"
            :key="lead.id"
            type="button"
            class="lead-card"
            :class="{ 'lead-card--active': lead.id === leadInbox.selectedLeadId }"
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

            <dl class="lead-card__facts">
              <div>
                <dt>Телефон</dt>
                <dd>{{ lead.phone }}</dd>
              </div>
              <div>
                <dt>Гостей</dt>
                <dd>{{ formatGuestCount(lead.guestCount) }}</dd>
              </div>
              <div>
                <dt>Дата праздника</dt>
                <dd>{{ formatDate(lead.requestedDate) }}</dd>
              </div>
              <div>
                <dt>Создана</dt>
                <dd>{{ formatDateTime(lead.createdAt) }}</dd>
              </div>
            </dl>
          </button>
        </div>
      </section>

      <aside class="admin-panel admin-panel--stack">
        <template v-if="!leadInbox.selectedLeadId">
          <StatePanel
            title="Выберите заявку"
            description="Когда вы выберете обращение слева, здесь появятся детали клиента, пакет, комментарий и управление статусом."
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
                  <dd>{{ leadInbox.selectedLead.phone }}</dd>
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
    return '1 заявка в работе';
  }
  return `${count} заявок в работе`;
});

const filterSummary = computed(() => {
  if (!leadInbox.hasActiveFilters) {
    return 'Показаны все обращения без дополнительных фильтров.';
  }

  return 'Показаны только заявки, которые соответствуют текущим фильтрам.';
});

const statusSummaryLabel = computed(() => {
  if (leadInbox.isListLoading) {
    return 'Обновляем список';
  }

  return leadInbox.hasActiveFilters ? 'Фильтры включены' : 'Все заявки';
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
</script>

<style scoped>
.leads-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.leads-meta__title,
.leads-meta__hint {
  margin: 0;
}

.leads-meta__title {
  font-size: 15px;
  font-weight: 700;
}

.leads-meta__hint {
  margin-top: 4px;
  color: var(--color-muted);
  line-height: 1.5;
}

.lead-card {
  display: grid;
  gap: 16px;
  width: 100%;
  padding: 18px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: var(--color-surface);
  text-align: left;
  cursor: pointer;
  transition:
    border-color 120ms ease,
    box-shadow 120ms ease,
    background-color 120ms ease;
}

.lead-card:hover,
.lead-card--active {
  border-color: rgba(208, 47, 112, 0.24);
  background: #fffafd;
  box-shadow: 0 10px 24px rgba(208, 47, 112, 0.08);
}

.lead-card__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.lead-card__title strong {
  display: block;
  font-size: 16px;
  line-height: 1.4;
}

.lead-card__title p {
  margin: 4px 0 0;
  color: var(--color-muted);
  line-height: 1.5;
}

.lead-card__facts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px 18px;
  margin: 0;
}

.lead-card__facts div,
.lead-detail-card__list div {
  display: grid;
  gap: 4px;
}

.lead-card__facts dt,
.lead-detail-card__list dt {
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 600;
}

.lead-card__facts dd,
.lead-detail-card__list dd {
  margin: 0;
  line-height: 1.45;
}

.lead-detail__header {
  display: grid;
  gap: 12px;
}

.lead-detail__copy {
  display: grid;
  gap: 8px;
}

.lead-detail__eyebrow {
  margin: 0;
  color: var(--color-accent);
  font-size: 13px;
  font-weight: 700;
}

.lead-detail__title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.lead-detail__title-row h2 {
  margin: 0;
  font-size: 24px;
  line-height: 1.2;
}

.lead-detail__description {
  margin: 0;
  color: var(--color-muted);
  line-height: 1.6;
}

.lead-status-panel {
  display: grid;
  gap: 16px;
  padding: 20px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: var(--color-surface-subtle);
}

.lead-status-panel__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.lead-status-button {
  min-height: 40px;
  padding: 0 14px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  color: var(--color-text);
  cursor: pointer;
  transition:
    border-color 120ms ease,
    background-color 120ms ease,
    color 120ms ease;
}

.lead-status-button--active {
  border-color: rgba(208, 47, 112, 0.28);
  background: var(--color-accent-soft);
  color: var(--color-accent);
  font-weight: 700;
}

.lead-detail-card {
  display: grid;
  gap: 14px;
  padding: 18px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: var(--color-surface-subtle);
}

.lead-detail-card--full {
  grid-column: 1 / -1;
}

.lead-detail-card__list {
  display: grid;
  gap: 12px;
  margin: 0;
}

.lead-detail-card__notes {
  margin: 0;
  line-height: 1.6;
  color: var(--color-text);
}

@media (max-width: 900px) {
  .leads-meta,
  .lead-card__header,
  .lead-detail__title-row {
    flex-direction: column;
    align-items: flex-start;
  }

  .lead-card__facts {
    grid-template-columns: 1fr;
  }
}
</style>
