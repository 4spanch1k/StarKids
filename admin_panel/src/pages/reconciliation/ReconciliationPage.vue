<template>
  <PageShell
    eyebrow="Операции"
    title="Проверка платежей"
    description="Только сохранённые ошибки callback и незавершённые шаги после подтверждённой оплаты. Эта страница ничего не меняет в платеже."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--secondary"
        :disabled="isLoading"
        @click="void loadItems()"
      >
        {{ isLoading ? 'Обновляем…' : 'Обновить' }}
      </button>
    </template>

    <StatePanel
      v-if="isLoading && items.length === 0"
      title="Загружаем ошибки платежей"
      description="Проверяем сохранённые маркеры ticket issuance, loyalty settlement и callback mismatch."
    />
    <StatePanel
      v-else-if="errorMessage"
      title="Не удалось загрузить reconciliation"
      :description="errorMessage"
      tone="error"
    >
      <template #actions>
        <button type="button" class="admin-button admin-button--secondary" @click="void loadItems()">
          Повторить
        </button>
      </template>
    </StatePanel>
    <StatePanel
      v-else-if="items.length === 0"
      title="Проблемных платежей нет"
      description="Все сохранённые paid-платежи прошли ticket и loyalty шаги."
    />
    <section v-else class="admin-panel admin-panel--stack">
      <div class="admin-section-heading">
        <h2>Нужно проверить: {{ total }}</h2>
        <p>Изменение статуса или возврат денег выполняются только через подтверждённый provider flow.</p>
      </div>
      <div class="reconciliation-table-wrap">
        <table class="reconciliation-table">
          <thead>
            <tr>
              <th>Заказ</th>
              <th>Клиент</th>
              <th>Филиал</th>
              <th>Сумма</th>
              <th>Проблема</th>
              <th>Последняя ошибка</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in items" :key="item.paymentId">
              <td>
                <strong>{{ item.localOrderId }}</strong>
                <span class="muted">{{ formatDate(item.createdAt) }}</span>
                <span v-if="item.paidAt" class="muted">Оплата: {{ formatDate(item.paidAt) }}</span>
              </td>
              <td>{{ item.customer }}</td>
              <td>{{ item.branchName }}</td>
              <td>{{ formatMoney(item.amountTenge) }}</td>
              <td>{{ issueLabel(item.issueType) }}</td>
              <td>{{ item.lastFailure || '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </PageShell>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';

import { fetchReconciliationItems } from '@/features/reconciliation/api/adminReconciliationApi';
import type { ReconciliationItem } from '@/features/reconciliation/model/reconciliation';
import {
  executeAuthorizedAdminRequest,
  resolveAdminRequestError,
} from '@/features/auth/lib/adminRequest';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';

const items = ref<ReconciliationItem[]>([]);
const total = ref(0);
const isLoading = ref(false);
const errorMessage = ref('');

onMounted(() => void loadItems());

async function loadItems() {
  isLoading.value = true;
  errorMessage.value = '';
  try {
    const response = await executeAuthorizedAdminRequest((accessToken) =>
      fetchReconciliationItems({ accessToken }),
    );
    items.value = response.items;
    total.value = response.total;
  } catch (error) {
    errorMessage.value = resolveAdminRequestError(
      error,
      'Не удалось загрузить список проблемных платежей.',
    );
  } finally {
    isLoading.value = false;
  }
}

function issueLabel(value: string): string {
  return {
    callback_validation_mismatch: 'Несоответствие callback',
    ticket_issuance_pending: 'Билет не выпущен',
    loyalty_settlement_pending: 'Бонусы не рассчитаны',
  }[value] ?? value;
}

function formatMoney(value: number): string {
  return `${value.toLocaleString('ru-RU')} ₸`;
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat('ru-RU', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Almaty',
  }).format(new Date(value));
}
</script>

<style scoped>
.reconciliation-table-wrap {
  overflow-x: auto;
}

.reconciliation-table {
  width: 100%;
  border-collapse: collapse;
}

.reconciliation-table th,
.reconciliation-table td {
  padding: 12px;
  border-bottom: 1px solid var(--color-border);
  text-align: left;
  vertical-align: top;
}

.reconciliation-table td strong,
.reconciliation-table td .muted {
  display: block;
}

.muted {
  margin-top: 4px;
  color: var(--color-muted);
  font-size: 12px;
}
</style>
