<template>
  <PageShell
    eyebrow="Операционный контур"
    title="Заявки"
    description="Очередь входящих обращений и рабочие статусы."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--secondary"
        :disabled="leadInbox.isListLoading"
        @click="handleRefreshLeads"
      >
        {{ leadInbox.isListLoading ? 'Обновляем…' : 'Обновить список' }}
      </button>
    </template>

    <section class="admin-panel admin-panel--stack">
      <form class="lead-filters" @submit.prevent="applyLeadFilters">
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
            @click="resetLeadFilters"
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
      <section
        class="admin-panel admin-panel--stack lead-queue leads-mobile-section"
        :class="{ 'leads-mobile-section--hidden': showDetailRoutePanel }"
      >
        <div class="admin-section-heading">
          <h2>Очередь заявок</h2>
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
              @click="handleRefreshLeads"
            >
              Повторить
            </button>
          </template>
        </StatePanel>

        <StatePanel
          v-else-if="leadInbox.leads.length === 0"
          title="По этим фильтрам заявок нет"
          :description="emptyStateDescription"
        >
          <template #actions>
            <button
              type="button"
              class="admin-button admin-button--primary"
              :disabled="!leadInbox.hasActiveFilters"
              @click="resetLeadFilters"
            >
              Сбросить фильтры
            </button>
          </template>
        </StatePanel>

        <div v-else class="lead-queue__list">
          <article
            v-for="lead in visibleLeads"
            :key="lead.id"
            class="lead-row"
            :class="{ 'lead-row--active': lead.id === leadInbox.selectedLeadId }"
          >
            <button
              type="button"
              class="lead-row__main"
              @click="void handleSelectLead(lead.id)"
            >
              <span class="lead-row__content">
                <span class="lead-row__topline">
                  <strong class="lead-row__name">{{ lead.customerName }}</strong>
                  <StatusBadge
                    :label="formatStatus(lead.status)"
                    :tone="statusTone(lead.status)"
                  />
                </span>

                <span class="lead-row__meta">
                  <span class="lead-row__phone">{{ lead.phone }}</span>
                  <span>{{ formatType(lead.type) }}</span>
                  <span>{{ formatDateTime(lead.createdAt) }}</span>
                </span>

                <span class="lead-row__subline">
                  <span>{{ formatSource(lead.source) }}</span>
                  <span
                    class="lead-row__deadline"
                    :class="deadlineClass(lead.type, lead.requestedDate)"
                  >
                    {{ deadlineLabel(lead.type, lead.requestedDate) }}
                  </span>
                  <span v-if="lead.type === 'birthday_request'">
                    {{ formatGuestCount(lead.guestCount) }}
                  </span>
                </span>
              </span>

              <span class="lead-row__actions" aria-hidden="true">
                <span class="lead-row__chevron">›</span>
              </span>
            </button>

            <a
              class="lead-row__call"
              :href="formatTelHref(lead.phone)"
              aria-label="Позвонить клиенту"
              title="Позвонить"
              @click.stop
            >
              <svg
                aria-hidden="true"
                viewBox="0 0 20 20"
                focusable="false"
              >
                <path
                  d="M6.6 3.2 8 6.5c.2.5.1 1-.3 1.3l-.8.7c.8 1.7 2.1 3 3.8 3.8l.7-.8c.3-.4.9-.5 1.3-.3l3.2 1.4c.5.2.8.8.6 1.4l-.5 1.8c-.2.7-.8 1.1-1.5 1.1C8.2 16.9 3.1 11.8 3.1 5.5c0-.7.5-1.3 1.1-1.5L6 3.5c.3-.1.5-.2.6-.3Z"
                  fill="currentColor"
                />
              </svg>
            </a>
          </article>

          <div
            v-if="hasMoreLeads"
            class="lead-queue__load-more"
          >
            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="loadMoreLeads"
            >
              Загрузить еще
            </button>
            <span>
              Показано {{ visibleLeads.length }} из {{ leadInbox.leads.length }}
            </span>
          </div>
        </div>
      </section>

      <aside
        v-if="isDesktopView"
        class="admin-panel admin-panel--stack lead-detail leads-mobile-section"
      >
        <template v-if="!leadInbox.selectedLeadId">
          <StatePanel
            title="Выберите заявку"
            description="Откройте обращение, чтобы увидеть детали и изменить статус."
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
          <LeadDetailView
            :lead="leadInbox.selectedLead"
            :is-status-updating="leadInbox.isStatusUpdating"
            :status-success-message="leadInbox.statusSuccessMessage"
            :status-error-message="leadInbox.statusErrorMessage"
            @update-status="leadInbox.updateLeadStatus"
          />
        </template>
      </aside>
    </div>

    <AdminRoutePanel
      :open="showDetailRoutePanel"
      :title="selectedLeadTitle"
      eyebrow="Карточка заявки"
      close-label="К списку"
      variant="detail"
      @close="void handleBackToList()"
    >
      <template v-if="leadInbox.isDetailLoading && !leadInbox.selectedLead">
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

      <LeadDetailView
        v-else-if="leadInbox.selectedLead"
        :lead="leadInbox.selectedLead"
        :is-status-updating="leadInbox.isStatusUpdating"
        :status-success-message="leadInbox.statusSuccessMessage"
        :status-error-message="leadInbox.statusErrorMessage"
        @update-status="leadInbox.updateLeadStatus"
      />
    </AdminRoutePanel>
  </PageShell>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import {
  formatLeadStatus as formatStatus,
  formatLeadType as formatType,
  leadStatuses,
  type LeadStatus,
  type LeadType,
} from '@/entities/lead/model/lead';
import { useLeadInbox } from '@/features/leads/model/useLeadInbox';
import LeadDetailView from '@/features/leads/ui/LeadDetailView.vue';
import { useAdminCrudRouteState } from '@/shared/composables/useAdminCrudRouteState';
import AdminRoutePanel from '@/shared/ui/AdminRoutePanel.vue';
import AppDateRangeField from '@/shared/ui/AppDateRangeField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const leadInbox = reactive(useLeadInbox());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.leads.list,
  detailRouteName: adminCrudRouteNames.leads.detail,
  idParam: adminCrudRouteNames.leads.idParam,
});
const leadPageSize = 20;
const visibleLeadLimit = ref(leadPageSize);

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

  return buildFilterExplanation({ includeBranchCaveat: true });
});

const newLeadCount = computed(() => {
  return leadInbox.leads.filter((lead) => lead.status === 'new').length;
});

const inProgressLeadCount = computed(() => {
  return leadInbox.leads.filter((lead) => lead.status === 'in_progress').length;
});

const urgentLeadCount = computed(() => {
  return leadInbox.leads.filter((lead) => deadlineTone(lead.type, lead.requestedDate) === 'danger').length;
});

const visibleLeads = computed(() => {
  return leadInbox.leads.slice(0, visibleLeadLimit.value);
});

const hasMoreLeads = computed(() => {
  return visibleLeadLimit.value < leadInbox.leads.length;
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

const selectedBranchLabel = computed(() => {
  const selectedBranch = leadInbox.branchOptions.find(
    (branch) => branch.id === leadInbox.filters.branchId,
  );

  return selectedBranch?.shortLabel ?? 'выбранный филиал';
});

const emptyStateDescription = computed(() => {
  if (leadInbox.hasActiveFilters) {
    const explanation = buildFilterExplanation({ includeBranchCaveat: true });
    return `По этим условиям заявок не найдено. ${explanation}`;
  }

  return 'Измените период, филиал или статус, чтобы вернуть обращения в очередь.';
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

const selectedLeadTitle = computed(() => {
  return leadInbox.selectedLead?.customerName || 'Карточка заявки';
});

const routeMode = computed(() => routeState.mode.value);
const showDetailRoutePanel = computed(() => routeState.showDetailRoutePanel.value);
const isDesktopView = computed(() => routeState.isDesktop.value);

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

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, leadId]) => {
    if (mode === 'detail' && leadId) {
      await leadInbox.selectLead(leadId);
    }
  },
  { immediate: true },
);

watch(
  () => leadInbox.selectedLeadId,
  async (leadId) => {
    if (!leadId && routeMode.value === 'detail') {
      await routeState.goToList();
    }
  },
);

async function handleSelectLead(leadId: string) {
  await routeState.goToDetail(leadId);
}

async function handleBackToList() {
  await routeState.closeDetail();
}

async function handleRefreshLeads() {
  await leadInbox.loadLeads();
}

async function applyLeadFilters() {
  resetLeadPagination();
  await leadInbox.loadLeads();
}

async function resetLeadFilters() {
  resetLeadPagination();
  await leadInbox.resetFilters();
}

function loadMoreLeads() {
  visibleLeadLimit.value = Math.min(
    visibleLeadLimit.value + leadPageSize,
    leadInbox.leads.length,
  );
}

function resetLeadPagination() {
  visibleLeadLimit.value = leadPageSize;
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

function formatDateRangeSummary(from: string, to: string): string {
  if (from && to) {
    return `${formatDate(from)} - ${formatDate(to)}`;
  }

  if (from) {
    return `с ${formatDate(from)}`;
  }

  if (to) {
    return `до ${formatDate(to)}`;
  }

  return '';
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

function formatSource(value: string): string {
  const labels: Record<string, string> = {
    mobile_app: 'Мобильное приложение',
  };

  return labels[value] ?? value;
}

function formatTelHref(phone: string): string {
  return `tel:${phone.replace(/[^\d+]/g, '')}`;
}

function buildFilterExplanation(options?: { includeBranchCaveat?: boolean }): string {
  const notes: string[] = [];

  if (leadInbox.filters.branchId) {
    notes.push(`Филиал: ${selectedBranchLabel.value}.`);

    if (options?.includeBranchCaveat) {
      notes.push('Контактные обращения без привязки к филиалу этим фильтром скрываются.');
    }
  }

  if (leadInbox.filters.status) {
    notes.push(`Статус: ${formatStatus(leadInbox.filters.status)}.`);
  }

  const dateRangeSummary = formatDateRangeSummary(
    leadInbox.filters.createdFrom,
    leadInbox.filters.createdTo,
  );
  if (dateRangeSummary) {
    notes.push(`Период: ${dateRangeSummary}.`);
  }

  return notes.join(' ');
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

function deadlineTone(
  type: LeadType,
  value: string | null,
): 'neutral' | 'warning' | 'danger' {
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

.leads-mobile-section {
  min-height: 0;
}

.lead-queue__list {
  max-height: calc(100vh - 290px);
  overflow-y: auto;
  padding-right: 2px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
}

.lead-row {
  position: relative;
  display: grid;
  grid-template-columns: minmax(0, 1fr) 36px;
  align-items: stretch;
  border-bottom: 1px solid var(--color-border);
  transition:
    background-color 120ms ease;
}

.lead-row:last-of-type {
  border-bottom: 0;
}

.lead-row:hover,
.lead-row--active {
  background: #fffafd;
}

.lead-row--active::before {
  position: absolute;
  inset: 0 auto 0 0;
  width: 3px;
  border-radius: 999px;
  background: var(--color-accent);
  content: '';
}

.lead-row__main {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 18px;
  align-items: center;
  gap: 8px;
  min-width: 0;
  padding: 10px 10px 10px 14px;
  border: 0;
  background: transparent;
  color: inherit;
  text-align: left;
  cursor: pointer;
}

.lead-row__main:focus-visible,
.lead-row__call:focus-visible {
  outline: 2px solid rgba(208, 47, 112, 0.38);
  outline-offset: -2px;
}

.lead-row__content {
  display: grid;
  min-width: 0;
  gap: 4px;
}

.lead-row__topline,
.lead-row__meta,
.lead-row__subline {
  display: flex;
  align-items: center;
  min-width: 0;
}

.lead-row__topline {
  justify-content: space-between;
  gap: 8px;
}

.lead-row__meta,
.lead-row__subline {
  gap: 2px;
  color: var(--color-muted);
  font-size: 12px;
  line-height: 1.35;
}

.lead-row__meta > span,
.lead-row__subline > span {
  overflow: hidden;
  min-width: 0;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.lead-row__meta > span:not(:last-child)::after,
.lead-row__subline > span:not(:last-child)::after {
  margin: 0 6px;
  color: var(--color-border-strong);
  content: '•';
}

.lead-row__name {
  overflow: hidden;
  min-width: 0;
  font-size: 14px;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.lead-row__phone {
  color: var(--color-text);
  font-weight: 700;
}

.lead-row__deadline {
  font-weight: 600;
}

.lead-row__actions {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--color-muted);
}

.lead-row__chevron {
  font-size: 22px;
  line-height: 1;
}

.lead-row__call {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  min-height: 100%;
  border-left: 1px solid var(--color-border);
  color: var(--color-muted);
  text-decoration: none;
  transition:
    background-color 120ms ease,
    color 120ms ease;
}

.lead-row__call:hover {
  background: var(--color-surface-subtle);
  color: var(--color-accent);
}

.lead-row__call svg {
  width: 17px;
  height: 17px;
}

.lead-deadline--neutral {
  color: var(--color-text);
}

.lead-deadline--warning {
  color: var(--color-warning);
}

.lead-deadline--danger {
  color: var(--color-danger);
}

.lead-queue__load-more {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 12px;
  border-top: 1px solid var(--color-border);
  color: var(--color-muted);
  font-size: 12px;
}

.lead-detail {
  position: sticky;
  top: 18px;
  max-height: calc(100vh - 128px);
  overflow-y: auto;
}

@media (max-width: 1280px) {
  .lead-filters {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 900px) {
  .leads-mobile-section--hidden {
    display: none;
  }

  .leads-toolbar {
    flex-direction: column;
    align-items: flex-start;
  }

  .lead-detail {
    position: static;
    max-height: none;
  }
}

@media (max-width: 720px) {
  .lead-filters {
    grid-template-columns: 1fr;
  }

  .lead-filters__actions,
  .leads-toolbar__badges {
    width: 100%;
    justify-content: flex-start;
  }

  .lead-queue__list {
    max-height: none;
  }

  .lead-row {
    grid-template-columns: minmax(0, 1fr) 40px;
  }

  .lead-row__main {
    padding-block: 9px;
  }
}
</style>
