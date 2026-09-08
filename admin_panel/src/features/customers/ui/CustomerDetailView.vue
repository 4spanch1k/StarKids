<template>
  <StatePanel
    v-if="isLoading"
    title="Загружаем карточку клиента"
    description="Собираем детей, посещения, оплаты, бонусы и заявки."
  />
  <StatePanel
    v-else-if="errorMessage"
    title="Не удалось открыть карточку"
    :description="errorMessage"
    tone="error"
  >
    <template #actions>
      <button type="button" class="admin-button admin-button--secondary" @click="$emit('retry')">
        Повторить
      </button>
    </template>
  </StatePanel>
  <StatePanel
    v-else-if="!customer"
    title="Выберите клиента"
    description="Откройте строку слева, чтобы увидеть подтверждённую историю клиента."
  />
  <div v-else class="customer-detail">
    <header class="customer-detail__header">
      <div>
        <p class="customer-detail__eyebrow">{{ customer.customer.isActive ? 'Активный клиент' : 'Неактивный клиент' }}</p>
        <h2>{{ displayName(customer.customer) }}</h2>
        <p class="customer-detail__contact">
          {{ customer.customer.phone || 'Телефон не указан' }}<span v-if="customer.customer.email"> · {{ customer.customer.email }}</span>
        </p>
      </div>
    </header>

    <dl class="customer-metrics">
      <div><dt>Дети</dt><dd>{{ customer.metrics.childrenCount }}</dd></div>
      <div><dt>Визиты</dt><dd>{{ customer.metrics.visitsCount }}</dd></div>
      <div><dt>Первый визит</dt><dd>{{ formatDateTime(customer.metrics.firstVisitAt) }}</dd></div>
      <div><dt>Последний визит</dt><dd>{{ formatDateTime(customer.metrics.lastVisitAt) }}</dd></div>
      <div><dt>Расходы на билеты</dt><dd>{{ formatMoney(customer.metrics.ticketCashSpendTenge) }}</dd></div>
    </dl>

    <section class="customer-detail__section">
      <div class="admin-section-heading"><h3>Лояльность</h3></div>
      <dl class="customer-inline-metrics">
        <div><dt>Баланс</dt><dd>{{ customer.loyalty.balance.toLocaleString('ru-RU') }}</dd></div>
        <div><dt>Начислено всего</dt><dd>{{ customer.loyalty.lifetimeEarned.toLocaleString('ru-RU') }}</dd></div>
        <div><dt>Использовано всего</dt><dd>{{ customer.loyalty.lifetimeSpent.toLocaleString('ru-RU') }}</dd></div>
      </dl>
    </section>

    <section class="customer-detail__section">
      <div class="admin-section-heading"><h3>Дети</h3></div>
      <p v-if="customer.children.length === 0" class="admin-copy-muted">Дети не добавлены.</p>
      <ul v-else class="customer-record-list">
        <li v-for="child in customer.children" :key="child.id">
          <strong>{{ child.name }}</strong>
          <span>{{ formatDate(child.birthDate) }} · {{ formatGender(child.gender) }}</span>
        </li>
      </ul>
    </section>

    <section class="customer-detail__section">
      <div class="admin-section-heading"><h3>Последние визиты</h3></div>
      <p v-if="customer.recentVisits.length === 0" class="admin-copy-muted">Посещений пока нет.</p>
      <ul v-else class="customer-record-list">
        <li v-for="visit in customer.recentVisits" :key="visit.id">
          <strong>{{ formatDateTime(visit.startedAt) }}</strong>
          <span>{{ visit.branch?.shortLabel || visit.branch?.name || 'Филиал не указан' }} · {{ formatVisitStatus(visit.status) }}</span>
        </li>
      </ul>
    </section>

    <section class="customer-detail__section">
      <div class="admin-section-heading"><h3>Покупки билетов</h3></div>
      <p v-if="customer.recentTicketPurchases.length === 0" class="admin-copy-muted">Покупок билетов пока нет.</p>
      <ul v-else class="customer-record-list">
        <li v-for="purchase in customer.recentTicketPurchases" :key="purchase.id">
          <strong>{{ purchase.localOrderId }} · {{ formatMoney(purchase.cashAmountTenge) }}</strong>
          <span>
            {{ formatDateTime(purchase.paidAt) }} · {{ purchase.quantity }} бил. ·
            {{ purchase.branch?.shortLabel || purchase.branch?.name || 'Филиал не указан' }} ·
            {{ formatPaymentStatus(purchase.status) }} ·
            всего {{ formatMoney(purchase.grossAmountTenge) }} ·
            бонусы {{ purchase.bonusAmount.toLocaleString('ru-RU') }}
          </span>
        </li>
      </ul>
    </section>

    <section class="customer-detail__section">
      <div class="admin-section-heading"><h3>Заявки на праздник</h3></div>
      <p v-if="customer.birthdayLeads.length === 0" class="admin-copy-muted">Заявок на праздник нет.</p>
      <ul v-else class="customer-record-list">
        <li v-for="lead in customer.birthdayLeads" :key="lead.id">
          <strong>{{ lead.childName || 'Ребёнок не указан' }} · {{ lead.packageName || 'Пакет не указан' }}</strong>
          <span>
            {{ formatDate(lead.desiredDate) }} · {{ formatLeadStatus(lead.status) }} ·
            {{ lead.branch?.shortLabel || lead.branch?.name || 'Филиал не указан' }}
            <template v-if="lead.agreedAmountTenge !== null"> · согласовано {{ formatMoney(lead.agreedAmountTenge) }}</template>
            <template v-if="lead.status === 'lost'"> · {{ formatLostReason(lead.lostReason) }}</template>
          </span>
        </li>
      </ul>
    </section>
  </div>
</template>

<script setup lang="ts">
import type { CustomerDetail } from '@/features/customers/model/customer';
import StatePanel from '@/shared/ui/StatePanel.vue';

defineProps<{
  customer: CustomerDetail | null;
  isLoading: boolean;
  errorMessage: string;
}>();

defineEmits<{
  retry: [];
}>();

function displayName(customer: { firstName: string | null; lastName: string | null; phone: string | null; email: string | null }): string {
  const fullName = [customer.firstName, customer.lastName].filter(Boolean).join(' ').trim();
  return fullName || customer.phone || customer.email || 'Без имени';
}

function formatDate(value: string | null): string {
  if (!value) return 'Не указана';
  return new Intl.DateTimeFormat('ru-RU', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(`${value}T00:00:00`));
}

function formatDateTime(value: string | null): string {
  if (!value) return 'Никогда';
  return new Intl.DateTimeFormat('ru-RU', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(value));
}

function formatMoney(value: number): string {
  return `${value.toLocaleString('ru-RU')} ₸`;
}

function formatGender(value: string): string {
  return ({ male: 'мальчик', female: 'девочка', unspecified: 'пол не указан' } as Record<string, string>)[value] ?? 'пол не указан';
}

function formatVisitStatus(value: string): string {
  return ({ active: 'активный', completed: 'завершённый' } as Record<string, string>)[value] ?? value;
}

function formatPaymentStatus(value: string): string {
  return ({ paid: 'оплачено', failed: 'ошибка оплаты', canceled: 'отменено', expired: 'истёк' } as Record<string, string>)[value] ?? value;
}

function formatLeadStatus(value: string): string {
  return ({ new: 'Новая', contacted: 'Менеджер связался', qualified: 'Квалифицирована', booked: 'Забронировано', completed: 'Проведено', in_progress: 'В работе', confirmed: 'Подтверждена', cancelled: 'Отменена', lost: 'Не состоялась', closed: 'Закрыта' } as Record<string, string>)[value] ?? value;
}

function formatLostReason(value: string | null): string {
  return ({ too_expensive: 'Слишком дорого', date_unavailable: 'Дата занята', no_answer: 'Не дозвонились', competitor: 'Выбрали конкурента', changed_mind: 'Передумали', other_branch: 'Другой филиал', later: 'Позже', other: 'Другое' } as Record<string, string>)[value ?? ''] ?? 'Причина не указана';
}
</script>

<style scoped>
.customer-detail {
  display: grid;
  gap: 16px;
}

.customer-detail__header {
  display: flex;
  justify-content: space-between;
  gap: 12px;
}

.customer-detail__header h2,
.customer-detail__eyebrow,
.customer-detail__contact {
  margin: 0;
}

.customer-detail__eyebrow {
  color: var(--color-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.customer-detail__contact {
  margin-top: 5px;
  color: var(--color-muted);
  font-size: 13px;
}

.customer-metrics,
.customer-inline-metrics {
  display: grid;
  gap: 10px;
  margin: 0;
}

.customer-metrics {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.customer-inline-metrics {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.customer-metrics div,
.customer-inline-metrics div {
  padding: 10px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface-subtle);
}

.customer-metrics dt,
.customer-inline-metrics dt {
  color: var(--color-muted);
  font-size: 11px;
}

.customer-metrics dd,
.customer-inline-metrics dd {
  margin: 4px 0 0;
  font-weight: 700;
  line-height: 1.35;
}

.customer-detail__section {
  display: grid;
  gap: 8px;
  padding-top: 4px;
}

.customer-record-list {
  display: grid;
  gap: 7px;
  padding: 0;
  margin: 0;
  list-style: none;
}

.customer-record-list li {
  display: grid;
  gap: 3px;
  padding: 9px 10px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface-subtle);
  font-size: 13px;
}

.customer-record-list span {
  color: var(--color-muted);
  font-size: 12px;
}

@media (max-width: 560px) {
  .customer-metrics,
  .customer-inline-metrics {
    grid-template-columns: 1fr;
  }
}
</style>
