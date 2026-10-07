<template>
  <PageShell
    eyebrow="Владелец"
    title="Дашборд"
    description="Подтверждённые показатели билетных оплат, посещений и бонусов. Период задаётся по времени Asia/Almaty."
  >
    <template #actions>
      <div class="period-switcher" role="group" aria-label="Период отчёта">
        <button
          v-for="option in periodOptions"
          :key="option.value"
          type="button"
          class="admin-button admin-button--secondary"
          :class="{ 'period-switcher__button--active': selectedPeriod === option.value }"
          :disabled="isLoading"
          @click="void selectPeriod(option.value)"
        >
          {{ option.label }}
        </button>
      </div>
      <button
        type="button"
        class="admin-button admin-button--secondary"
        :disabled="isLoading"
        @click="void loadDashboard()"
      >
        {{ isLoading ? 'Обновляем…' : 'Обновить' }}
      </button>
    </template>

    <StatePanel
      v-if="isLoading && !dashboard"
      title="Загружаем дашборд"
      description="Считаем показатели из оплаченных билетов, физических визитов и бонусного ledger."
    />
    <StatePanel
      v-else-if="errorMessage"
      title="Не удалось загрузить дашборд"
      :description="errorMessage"
      tone="error"
    >
      <template #actions>
        <button type="button" class="admin-button admin-button--secondary" @click="void loadDashboard()">
          Повторить
        </button>
      </template>
    </StatePanel>
    <template v-else-if="dashboard">
      <p class="dashboard-period">
        {{ periodLabel }} · {{ formatDateTime(dashboard.periodStart) }} — {{ formatDateTime(dashboard.periodEnd) }}
      </p>

      <section class="dashboard-section" aria-labelledby="operations-heading">
        <div class="admin-section-heading">
          <h2 id="operations-heading">Операции</h2>
          <p>Только settled ticket payments и реальные строки Visit.</p>
        </div>
        <div class="metric-grid metric-grid--four">
          <article v-for="metric in operationMetrics" :key="metric.label" class="metric-card">
            <p>{{ metric.label }}</p>
            <strong>{{ metric.value }}</strong>
          </article>
        </div>
      </section>

      <section class="dashboard-section" aria-labelledby="families-heading">
        <div class="admin-section-heading">
          <h2 id="families-heading">Семьи</h2>
          <p>Семья считается distinct MobileUser по истории физических визитов.</p>
        </div>
        <div class="metric-grid metric-grid--two">
          <article v-for="metric in familyMetrics" :key="metric.label" class="metric-card">
            <p>{{ metric.label }}</p>
            <strong>{{ metric.value }}</strong>
          </article>
        </div>
      </section>

      <section class="dashboard-section" aria-labelledby="bonuses-heading">
        <div class="admin-section-heading">
          <h2 id="bonuses-heading">Бонусы</h2>
          <p>Начисления и окончательные списания отделены от резерва.</p>
        </div>
        <div class="metric-grid metric-grid--three">
          <article v-for="metric in bonusMetrics" :key="metric.label" class="metric-card">
            <p>{{ metric.label }}</p>
            <strong>{{ metric.value }}</strong>
          </article>
        </div>
      </section>
    </template>
  </PageShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';

import { fetchOwnerDashboard } from '@/features/dashboard/api/ownerDashboardApi';
import type {
  OwnerDashboard,
  OwnerDashboardPeriod,
} from '@/features/dashboard/model/ownerDashboard';
import {
  executeAuthorizedAdminRequest,
  resolveAdminRequestError,
} from '@/features/auth/lib/adminRequest';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';

const periodOptions: Array<{ value: OwnerDashboardPeriod; label: string }> = [
  { value: 'today', label: 'Сегодня' },
  { value: '7d', label: '7 дней' },
  { value: '30d', label: '30 дней' },
];

const selectedPeriod = ref<OwnerDashboardPeriod>('today');
const dashboard = ref<OwnerDashboard | null>(null);
const isLoading = ref(false);
const errorMessage = ref('');
let requestVersion = 0;

const periodLabel = computed(() =>
  periodOptions.find((option) => option.value === selectedPeriod.value)?.label ?? 'Период',
);

const operationMetrics = computed(() => {
  if (!dashboard.value) return [];
  return [
    { label: 'Оплачено за билеты', value: formatMoney(dashboard.value.ticketCashCollectedTenge) },
    { label: 'Оплаченных покупок', value: formatNumber(dashboard.value.paidTicketPurchases) },
    { label: 'Продано билетов', value: formatNumber(dashboard.value.ticketsSold) },
    { label: 'Посещений', value: formatNumber(dashboard.value.visits) },
  ];
});

const familyMetrics = computed(() => {
  if (!dashboard.value) return [];
  return [
    { label: 'Новых семей', value: formatNumber(dashboard.value.newFamilies) },
    { label: 'Вернувшихся семей', value: formatNumber(dashboard.value.returningFamilies) },
  ];
});

const bonusMetrics = computed(() => {
  if (!dashboard.value) return [];
  return [
    { label: 'Начислено', value: formatBonuses(dashboard.value.bonusesIssued) },
    { label: 'Использовано', value: formatBonuses(dashboard.value.bonusesRedeemed) },
    { label: 'Бонусы на балансах', value: formatBonuses(dashboard.value.outstandingBonusBalance) },
  ];
});

onMounted(() => {
  void loadDashboard();
});

async function selectPeriod(period: OwnerDashboardPeriod) {
  if (period === selectedPeriod.value && dashboard.value) return;
  selectedPeriod.value = period;
  await loadDashboard();
}

async function loadDashboard() {
  const currentRequest = ++requestVersion;
  isLoading.value = true;
  errorMessage.value = '';

  try {
    const response = await executeAuthorizedAdminRequest((accessToken) =>
      fetchOwnerDashboard({ accessToken, period: selectedPeriod.value }),
    );
    if (currentRequest === requestVersion) {
      dashboard.value = response;
    }
  } catch (error) {
    if (currentRequest === requestVersion) {
      errorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить показатели владельца.',
      );
    }
  } finally {
    if (currentRequest === requestVersion) {
      isLoading.value = false;
    }
  }
}

function formatNumber(value: number): string {
  return value.toLocaleString('ru-RU');
}

function formatMoney(value: number): string {
  return `${formatNumber(value)} ₸`;
}

function formatBonuses(value: number): string {
  return `${formatNumber(value)} бонусов`;
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('ru-RU', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Asia/Almaty',
  }).format(new Date(value));
}
</script>

<style scoped>
.period-switcher {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.period-switcher__button--active {
  border-color: var(--color-accent);
  background: var(--color-accent-soft);
  color: var(--color-accent);
}

.dashboard-period {
  margin: 0;
  color: var(--color-muted);
  font-size: 13px;
}

.dashboard-section {
  display: grid;
  gap: 10px;
}

.metric-grid {
  display: grid;
  gap: 10px;
}

.metric-grid--four {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.metric-grid--three {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.metric-grid--two {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.metric-card {
  display: grid;
  gap: 8px;
  min-height: 92px;
  padding: 16px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  box-shadow: var(--shadow-soft);
}

.metric-card p,
.metric-card strong {
  margin: 0;
}

.metric-card p {
  color: var(--color-muted);
  font-size: 13px;
}

.metric-card strong {
  font-size: 24px;
  line-height: 1.15;
}

@media (max-width: 900px) {
  .metric-grid--four,
  .metric-grid--three {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 560px) {
  .metric-grid--four,
  .metric-grid--three,
  .metric-grid--two {
    grid-template-columns: 1fr;
  }

  .metric-card {
    min-height: 0;
  }
}
</style>
