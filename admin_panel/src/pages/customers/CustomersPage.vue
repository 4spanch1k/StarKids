<template>
  <PageShell
    eyebrow="Клиентская база"
    title="Клиенты"
    description="История семьи, посещений, билетных оплат, бонусов и заявок на праздник. Только для суперадминов."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--secondary"
        :disabled="customers.isListLoading"
        @click="void customers.loadCustomers(customers.page)"
      >
        {{ customers.isListLoading ? 'Обновляем…' : 'Обновить' }}
      </button>
    </template>

    <section class="admin-panel admin-panel--stack">
      <form class="customers-search" @submit.prevent="void customers.applySearch()">
        <AdminSearchField
          v-model="customers.search"
          label="Поиск клиента"
          placeholder="Имя, телефон или email"
        />
        <label class="customers-filter">
          <span>Сегмент по посещениям</span>
          <select v-model="customers.visitSegment" class="admin-control">
            <option value="">Все семьи</option>
            <option value="never_visited">Ещё не посещали</option>
            <option value="first_visit_only">Были 1 раз</option>
            <option value="returning">Возвращались</option>
            <option value="dormant_30">Не были 30+ дней</option>
            <option value="dormant_60">Не были 60+ дней</option>
            <option value="dormant_90">Не были 90+ дней</option>
          </select>
        </label>
        <button type="submit" class="admin-button admin-button--primary">
          Найти
        </button>
      </form>
      <p class="admin-copy-muted">
        Показаны {{ customers.items.length }} из {{ customers.total }} клиентов. Расходы — только реальные оплаты деньгами за билеты.
      </p>
    </section>

    <div class="admin-split-layout customers-layout">
      <section
        class="admin-panel admin-panel--stack customers-list-panel"
        :class="{ 'customers-list-panel--hidden': showDetailRoutePanel }"
      >
        <div class="admin-section-heading">
          <h2>Список клиентов</h2>
          <p>Сортировка: последний визит, затем дата регистрации.</p>
        </div>

        <StatePanel
          v-if="customers.isListLoading && customers.items.length === 0"
          title="Загружаем клиентов"
          description="Собираем агрегаты из текущих профилей и истории посещений."
        />
        <StatePanel
          v-else-if="customers.listErrorMessage"
          title="Не удалось загрузить клиентов"
          :description="customers.listErrorMessage"
          tone="error"
        >
          <template #actions>
            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="void customers.loadCustomers(customers.page)"
            >
              Повторить
            </button>
          </template>
        </StatePanel>
        <StatePanel
          v-else-if="customers.items.length === 0"
          title="Клиенты не найдены"
          description="Попробуйте изменить поисковый запрос."
        />
        <div v-else class="customers-table-wrap">
          <table class="customers-table">
            <thead>
              <tr>
                <th>Клиент</th>
                <th>Дети</th>
                <th>Визиты</th>
                <th>Тип визита</th>
                <th>Последний визит</th>
                <th>Дней с последнего</th>
                <th>Билеты</th>
                <th>Бонусы</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="customer in customers.items"
                :key="customer.id"
                :class="{ 'customers-table__row--active': customer.id === customers.selectedCustomerId }"
              >
                <td>
                  <button
                    type="button"
                    class="customers-table__customer"
                    @click="void routeState.goToDetail(customer.id)"
                  >
                    <strong>{{ displayName(customer) }}</strong>
                    <span>{{ customer.phone || customer.email || 'Контакты не указаны' }}</span>
                  </button>
                </td>
                <td>{{ customer.childrenCount }}</td>
                <td>{{ customer.visitsCount }}</td>
                <td>{{ visitTypeLabel(customer.customerVisitType) }}</td>
                <td>{{ formatDateTime(customer.lastVisitAt) }}</td>
                <td>{{ customer.daysSinceLastVisit ?? '—' }}</td>
                <td>{{ formatMoney(customer.ticketCashSpendTenge) }}</td>
                <td>{{ customer.bonusBalance.toLocaleString('ru-RU') }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div v-if="customers.totalPages > 1" class="customers-pagination">
          <button
            type="button"
            class="admin-button admin-button--secondary"
            :disabled="!customers.hasPreviousPage || customers.isListLoading"
            @click="void customers.loadCustomers(customers.page - 1)"
          >
            Назад
          </button>
          <span>Страница {{ customers.page }} из {{ customers.totalPages }}</span>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            :disabled="!customers.hasNextPage || customers.isListLoading"
            @click="void customers.loadCustomers(customers.page + 1)"
          >
            Далее
          </button>
        </div>
      </section>

      <aside v-if="isDesktopView" class="admin-panel admin-panel--stack customer-detail-panel">
        <CustomerDetailView
          :customer="customers.selectedCustomer"
          :is-loading="customers.isDetailLoading"
          :error-message="customers.detailErrorMessage"
          @retry="void retrySelectedCustomer()"
        />
      </aside>
    </div>

    <AdminRoutePanel
      :open="showDetailRoutePanel"
      :title="selectedCustomerTitle"
      eyebrow="Карточка клиента"
      close-label="К списку"
      variant="detail"
      @close="void handleBackToList()"
    >
      <CustomerDetailView
        :customer="customers.selectedCustomer"
        :is-loading="customers.isDetailLoading"
        :error-message="customers.detailErrorMessage"
        @retry="void retrySelectedCustomer()"
      />
    </AdminRoutePanel>
  </PageShell>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, watch } from 'vue';

import type { CustomerListItem } from '@/features/customers/model/customer';
import { useCustomers } from '@/features/customers/model/useCustomers';
import { useAdminCrudRouteState } from '@/shared/composables/useAdminCrudRouteState';
import AdminRoutePanel from '@/shared/ui/AdminRoutePanel.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import CustomerDetailView from '@/features/customers/ui/CustomerDetailView.vue';

const customers = reactive(useCustomers());
const routeState = useAdminCrudRouteState({
  listRouteName: 'customers',
  detailRouteName: 'customers-detail',
  idParam: 'customerId',
});

const isDesktopView = computed(() => routeState.isDesktop.value);
const showDetailRoutePanel = computed(() => routeState.showDetailRoutePanel.value);
const selectedCustomerTitle = computed(() => {
  const customer = customers.selectedCustomer?.customer;
  return customer ? displayName(customer) : 'Клиент';
});

onMounted(() => {
  void customers.initialize();
});

watch(
  () => routeState.activeId.value,
  (customerId) => {
    if (customerId) {
      void customers.selectCustomer(customerId);
    } else {
      customers.clearSelection();
    }
  },
  { immediate: true },
);

async function handleBackToList() {
  customers.clearSelection();
  await routeState.goToList();
}

async function retrySelectedCustomer() {
  if (customers.selectedCustomerId) {
    await customers.selectCustomer(customers.selectedCustomerId);
  }
}

function displayName(customer: Pick<CustomerListItem, 'firstName' | 'lastName' | 'phone' | 'email'>): string {
  const fullName = [customer.firstName, customer.lastName].filter(Boolean).join(' ').trim();
  return fullName || customer.phone || customer.email || 'Без имени';
}

function formatDateTime(value: string | null): string {
  if (!value) {
    return 'Никогда';
  }
  return new Intl.DateTimeFormat('ru-RU', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function formatMoney(value: number): string {
  return `${value.toLocaleString('ru-RU')} ₸`;
}

function visitTypeLabel(value: CustomerListItem['customerVisitType']): string {
  return {
    never_visited: 'Ещё не посещали',
    first_visit_only: 'Были 1 раз',
    returning: 'Возвращались',
  }[value];
}
</script>

<style scoped>
.customers-search {
  display: grid;
  grid-template-columns: minmax(240px, 1fr) minmax(190px, 240px) auto;
  gap: 10px;
  align-items: end;
}

.customers-filter {
  display: grid;
  gap: 5px;
  color: var(--color-muted);
  font-size: 12px;
}

.customers-layout {
  align-items: start;
}

.customers-list-panel {
  min-width: 0;
}

.customers-table-wrap {
  overflow-x: auto;
}

.customers-table {
  width: 100%;
  min-width: 720px;
  border-collapse: collapse;
  font-size: 13px;
}

.customers-table th,
.customers-table td {
  padding: 11px 10px;
  border-bottom: 1px solid var(--color-border);
  text-align: left;
  vertical-align: middle;
  white-space: nowrap;
}

.customers-table th {
  color: var(--color-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.customers-table__row--active {
  background: var(--color-accent-soft);
}

.customers-table__customer {
  display: grid;
  gap: 3px;
  min-width: 170px;
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  text-align: left;
  cursor: pointer;
}

.customers-table__customer strong {
  font-size: 14px;
}

.customers-table__customer span {
  color: var(--color-muted);
  font-size: 12px;
}

.customers-pagination {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding-top: 4px;
  color: var(--color-muted);
  font-size: 13px;
}

.customer-detail-panel {
  min-width: 0;
}

@media (max-width: 900px) {
  .customers-search {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 1100px) {
  .customers-list-panel--hidden {
    display: none;
  }
}

@media (max-width: 560px) {
  .customers-pagination {
    flex-wrap: wrap;
  }
}
</style>
