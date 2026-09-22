<template>
  <PageShell
    eyebrow="Коммуникации"
    title="Пуш-уведомления"
    description="Сообщение отправляется выбранной аудитории с активным push-токеном."
  >
    <p v-if="error" class="admin-inline-message admin-inline-message--error">{{ error }}</p>
    <p v-if="!providerConfigured" class="admin-inline-message admin-inline-message--error">
      FCM не настроен: отправка завершится понятным статусом ошибки, без имитации доставки.
    </p>
    <article v-if="journeyReport" class="admin-list-record" aria-label="Повторные посещения">
      <strong>Первый визит → второй визит</strong>
      <span>Участников: {{ journeyReport.eligible_families }} · Control: {{ journeyReport.control_size }} · Treatment: {{ journeyReport.treatment_size }}</span>
      <span>Treatment: принято FCM {{ journeyReport.treatment_delivered }} · открыли {{ journeyReport.treatment_opened }}</span>
      <span>Второй визит: Control {{ percent(journeyReport.control_second_visit_rate) }} · Treatment {{ percent(journeyReport.treatment_second_visit_rate) }} · uplift {{ uplift(journeyReport.absolute_uplift_percentage_points) }}</span>
    </article>
    <article v-if="reactivationReport" class="admin-list-record" aria-label="Reactivation V1">
      <strong>Reactivation V1</strong>
      <span>Семьи: {{ reactivationReport.eligible_families }} · Control: {{ reactivationReport.control_size }} · Treatment: {{ reactivationReport.treatment_size }}</span>
      <span>Treatment: доставлено {{ reactivationReport.treatment_delivered }} · открыто {{ reactivationReport.treatment_opened }}</span>
      <span>Повторный визит: Control {{ percent(reactivationReport.control_reactivation_rate) }} · Treatment {{ percent(reactivationReport.treatment_reactivation_rate) }} · uplift {{ uplift(reactivationReport.absolute_uplift_percentage_points) }}</span>
    </article>
    <article v-if="birthdayRevenueReport" class="admin-list-record" aria-label="Birthday Revenue CRM">
      <strong>Birthday Revenue CRM</strong>
      <span>Циклы: {{ birthdayRevenueReport.eligible_cycles }} · Control: {{ birthdayRevenueReport.control_cycles }} · Treatment: {{ birthdayRevenueReport.treatment_cycles }}</span>
      <span>D-30: {{ birthdayRevenueReport.windows['30']?.campaigns ?? 0 }} кампаний · доставлено {{ birthdayRevenueReport.windows['30']?.delivered ?? 0 }} · открыто {{ birthdayRevenueReport.windows['30']?.opened ?? 0 }}</span>
      <span>D-14: {{ birthdayRevenueReport.windows['14']?.campaigns ?? 0 }} кампаний · доставлено {{ birthdayRevenueReport.windows['14']?.delivered ?? 0 }} · открыто {{ birthdayRevenueReport.windows['14']?.opened ?? 0 }} · D-7: {{ birthdayRevenueReport.windows['7']?.campaigns ?? 0 }} · доставлено {{ birthdayRevenueReport.windows['7']?.delivered ?? 0 }} · открыто {{ birthdayRevenueReport.windows['7']?.opened ?? 0 }}</span>
      <span>Paid revenue: Control {{ money(birthdayRevenueReport.control.paid_revenue_tenge) }} · Treatment {{ money(birthdayRevenueReport.treatment.paid_revenue_tenge) }} · uplift {{ uplift(birthdayRevenueReport.absolute_uplift_percentage_points) }}</span>
    </article>

    <form class="admin-list-record" @submit.prevent="create">
      <input v-model.trim="form.title" class="admin-control" placeholder="Заголовок" maxlength="100" required />
      <textarea v-model.trim="form.body" class="admin-control" placeholder="Текст сообщения" maxlength="500" required />
      <select v-model="form.audience_mode" class="admin-control" aria-label="Аудитория">
        <option value="all">Все пользователи</option>
        <option value="birthday">Скоро день рождения ребёнка</option>
      </select>
      <label v-if="form.audience_mode === 'birthday'" class="admin-field">
        <span>День рождения ребёнка</span>
        <select v-model.number="form.birthday_days" class="admin-control" aria-label="Дни до дня рождения">
          <option :value="7">Через 7 дней</option>
          <option :value="14">Через 14 дней</option>
          <option :value="30">Через 30 дней</option>
        </select>
      </label>
      <select v-model="form.destination" class="admin-control" aria-label="Куда ведём">
        <option value="home">Главная</option>
        <option value="tickets">Билеты</option>
        <option value="birthdays">Праздники</option>
        <option value="promotions">Акции</option>
        <option value="profile">Профиль</option>
      </select>
      <select v-model="form.mode" class="admin-control" aria-label="Когда отправить">
        <option value="now">Отправить сейчас</option>
        <option value="scheduled">Запланировать</option>
      </select>
      <label v-if="form.mode === 'scheduled'" class="admin-field">
        <span>Дата и время, Asia/Almaty</span>
        <input v-model="form.scheduled_at" class="admin-control" type="datetime-local" required />
      </label>

      <div v-if="canSubmit" class="admin-list-record" aria-label="Предпросмотр уведомления">
        <strong>Предпросмотр</strong>
        <span>{{ form.title }}</span>
        <span>{{ form.body }}</span>
        <span>Куда ведёт: {{ destinationLabel(form.destination) }}</span>
        <span>Когда: {{ form.mode === 'now' ? 'сейчас' : formatInputDate(form.scheduled_at) }}</span>
        <span>Аудитория: {{ audienceLabel(currentAudience()) }}</span>
      </div>

      <div class="admin-page-actions">
        <button class="admin-button admin-button--secondary" type="button" :disabled="!canPreview || previewLoading" @click="preview">
          {{ previewLoading ? 'Проверяем…' : 'Проверить аудиторию' }}
        </button>
        <button class="admin-button admin-button--primary" type="submit" :disabled="saving || !canSubmit">
          {{ saving ? 'Отправляем…' : form.mode === 'now' ? 'Отправить сейчас' : 'Запланировать' }}
        </button>
      </div>
      <p v-if="previewResult" class="admin-inline-message">
        {{ audienceLabel(currentAudience()) }}: {{ previewResult.targeted_users }} семей · {{ previewResult.targeted_devices }} устройств.
      </p>
      <p v-if="previewResult && form.mode === 'now' && previewResult.targeted_users === 0" class="admin-inline-message admin-inline-message--error">
        Сейчас подходящих семей нет.
      </p>
      <p v-else-if="!previewMatchesCurrentAudience" class="admin-muted">
        Проверьте аудиторию перед отправкой.
      </p>
    </form>

    <StatePanel v-if="loading" title="Загружаем кампании" />
    <div v-else class="admin-list-records">
      <article v-for="campaign in campaigns" :key="campaign.id" class="admin-list-record">
        <div class="admin-list-record__copy">
          <strong>{{ campaign.title }}</strong>
          <span>{{ campaign.body }} · {{ destinationLabel(campaign.destination) }}</span>
          <span>Аудитория: {{ audienceLabel(campaign.audience) }} · {{ statusLabel(campaign.status) }}</span>
          <span v-if="campaign.status === 'scheduled' && campaign.scheduled_at">Отправка: {{ formatDateTime(campaign.scheduled_at) }} (Asia/Almaty)</span>
          <span v-if="campaign.failure_reason" class="admin-inline-message--error">Причина: {{ failureReasonLabel(campaign.failure_reason) }}</span>
          <small>Цель: {{ campaign.targeted_devices }} устройств · Принято FCM: {{ campaign.sent_count }} · Ошибки: {{ campaign.failed_count }} · Открытия: {{ campaign.opened_count }}</small>
          <small v-if="attributions[campaign.id]">Семей получили: {{ attributions[campaign.id].sent_users }} · Открыли семей: {{ attributions[campaign.id].opened_users }}</small>
          <small v-else-if="attributionLoading" class="admin-muted">Обновляем открытия…</small>
          <small v-else-if="attributionError" class="admin-inline-message--error">Открытия временно недоступны</small>
        </div>
        <div class="admin-page-actions">
          <button v-if="campaign.status === 'draft'" class="admin-button admin-button--primary" type="button" :disabled="sendingId === campaign.id" @click="send(campaign.id)">
            {{ sendingId === campaign.id ? 'Отправляем…' : 'Отправить сейчас' }}
          </button>
          <button v-if="campaign.status === 'draft' || campaign.status === 'scheduled'" class="admin-button admin-button--secondary" type="button" :disabled="sendingId === campaign.id" @click="cancel(campaign.id)">
            Отменить
          </button>
        </div>
      </article>
      <StatePanel v-if="campaigns.length === 0" title="Кампаний пока нет" description="Создайте первое уведомление для аудитории." />
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import { cancelPushCampaign, createPushCampaign, fetchBirthdayRevenueReport, fetchFirstSecondVisitReport, fetchPushCampaignAttribution, fetchReactivationReport, listPushCampaigns, previewPushAudience, sendPushCampaign, type BirthdayRevenueReport, type CampaignAudience, type FirstSecondVisitReport, type PushCampaign, type PushCampaignAttribution, type ReactivationReport } from '@/features/push-campaigns/api/pushCampaignsApi';

const campaigns = ref<PushCampaign[]>([]);
const attributions = reactive<Record<string, PushCampaignAttribution>>({});
const loading = ref(true);
const attributionLoading = ref(false);
const attributionError = ref(false);
const saving = ref(false);
const previewLoading = ref(false);
const sendingId = ref<string | null>(null);
const error = ref('');
const providerConfigured = ref(true);
const journeyReport = ref<FirstSecondVisitReport | null>(null);
const birthdayRevenueReport = ref<BirthdayRevenueReport | null>(null);
const reactivationReport = ref<ReactivationReport | null>(null);
const previewResult = ref<{ targeted_users: number; targeted_devices: number } | null>(null);
const previewAudienceKey = ref('');
const createIdempotencyKey = ref(newIdempotencyKey());
const form = reactive({ title: '', body: '', audience_mode: 'all' as 'all' | 'birthday', birthday_days: 14, destination: 'home' as PushCampaign['destination'], mode: 'now' as 'now' | 'scheduled', scheduled_at: '' });

const audienceKey = computed(() => JSON.stringify(currentAudience()));
const previewMatchesCurrentAudience = computed(() => previewAudienceKey.value === audienceKey.value);
const canPreview = computed(() => form.mode === 'now' || form.scheduled_at.length > 0);
const canSubmit = computed(() => form.title.trim().length > 0 && form.body.trim().length > 0 && (form.mode === 'now' || form.scheduled_at.length > 0) && previewMatchesCurrentAudience.value);

async function load() {
  loading.value = true;
  attributionLoading.value = true;
  attributionError.value = false;
  try {
    campaigns.value = await listPushCampaigns();
    journeyReport.value = await fetchFirstSecondVisitReport();
    birthdayRevenueReport.value = await fetchBirthdayRevenueReport();
    reactivationReport.value = await fetchReactivationReport();
    providerConfigured.value = campaigns.value.every((campaign) => campaign.push_provider_configured);
    const reports = await Promise.all(campaigns.value.map(async (campaign) => [campaign.id, await fetchPushCampaignAttribution(campaign.id)] as const));
    Object.keys(attributions).forEach((id) => delete attributions[id]);
    reports.forEach(([id, report]) => { attributions[id] = report; });
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Не удалось загрузить кампании';
    attributionError.value = true;
  } finally {
    loading.value = false;
    attributionLoading.value = false;
  }
}

function currentAudience(): CampaignAudience {
  return form.audience_mode === 'birthday'
    ? { type: 'birthday_in_days', days_before_birthday: form.birthday_days }
    : { type: 'all_users' };
}

async function preview() {
  previewLoading.value = true;
  error.value = '';
  const audience = currentAudience();
  const requestedAudienceKey = JSON.stringify(audience);
  try {
    previewResult.value = await previewPushAudience(audience);
    previewAudienceKey.value = requestedAudienceKey;
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Не удалось проверить аудиторию';
  } finally {
    previewLoading.value = false;
  }
}

async function create() {
  if (!canSubmit.value) return;
  const confirmation = previewResult.value?.targeted_users === 0 && form.mode === 'now'
    ? 'Сейчас подходящих семей нет. Всё равно поставить уведомление в отправку?'
    : `Отправить уведомление аудитории «${audienceLabel(currentAudience())}»?`;
  if (form.mode === 'now' && !window.confirm(confirmation)) return;
  saving.value = true;
  error.value = '';
  try {
    await createPushCampaign({
      internal_name: `manual-${createIdempotencyKey.value}`,
      title: form.title,
      body: form.body,
      audience: currentAudience(),
      destination: form.destination,
      scheduled_at: form.mode === 'scheduled' ? toAlmatyIso(form.scheduled_at) : null,
      send_now: form.mode === 'now',
      idempotency_key: createIdempotencyKey.value,
    });
    Object.assign(form, { title: '', body: '', audience_mode: 'all', birthday_days: 14, destination: 'home', mode: 'now', scheduled_at: '' });
    createIdempotencyKey.value = newIdempotencyKey();
    previewResult.value = null;
    previewAudienceKey.value = '';
    await load();
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Не удалось создать кампанию';
  } finally {
    saving.value = false;
  }
}

async function send(id: string) {
  if (sendingId.value || !window.confirm('Отправить уведомление сейчас?')) return;
  sendingId.value = id;
  error.value = '';
  try {
    await sendPushCampaign(id);
    await load();
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Не удалось отправить кампанию';
  } finally {
    sendingId.value = null;
  }
}

async function cancel(id: string) {
  try {
    await cancelPushCampaign(id);
    await load();
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Не удалось отменить кампанию';
  }
}

function destinationLabel(destination: PushCampaign['destination']): string {
  return ({ home: 'Главная', tickets: 'Билеты', birthdays: 'Праздники', promotions: 'Акции', profile: 'Профиль' } as Record<PushCampaign['destination'], string>)[destination];
}

function audienceLabel(audience: CampaignAudience): string {
  if (audience.type === 'birthday_in_days') {
    return `День рождения ребёнка через ${audience.days_before_birthday} дней`;
  }
  if (audience.type === 'visit_segment') return 'Сегмент посещений';
  if (audience.type === 'user') return 'Выбранный пользователь';
  return 'Все пользователи';
}

function statusLabel(status: string): string {
  return ({ draft: 'Черновик', scheduled: 'Запланировано', processing: 'Отправляется', sent: 'Отправлено', partially_failed: 'Частично отправлено', failed: 'Ошибка отправки', cancelled: 'Отменено' } as Record<string, string>)[status] ?? status;
}

function failureReasonLabel(reason: string): string {
  return ({ push_provider_not_configured: 'FCM не настроен', no_active_push_tokens: 'нет активных push-токенов', partial_delivery_failure: 'часть устройств не приняла сообщение', delivery_failed: 'FCM отклонил отправку' } as Record<string, string>)[reason] ?? reason;
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('ru-RU', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Almaty' }).format(new Date(value));
}

function formatInputDate(value: string): string { return value ? `${value.replace('T', ' ')} (Asia/Almaty)` : '—'; }

function toAlmatyIso(value: string): string { return new Date(`${value}:00+05:00`).toISOString(); }

function newIdempotencyKey(): string { return `push-${globalThis.crypto.randomUUID()}`; }
function percent(value: number | null): string { return value === null ? '—' : `${(value * 100).toFixed(1)}%`; }
function uplift(value: number | null): string { return value === null ? '—' : `${value >= 0 ? '+' : ''}${value.toFixed(1)} п.п.`; }
function money(value: number | null | undefined): string { return value == null ? '—' : `${Math.round(value).toLocaleString('ru-RU')} ₸`; }

watch(() => form.audience_mode, (mode) => {
  if (mode === 'birthday') form.destination = 'birthdays';
  previewResult.value = null;
  previewAudienceKey.value = '';
});

watch(() => form.birthday_days, () => {
  previewResult.value = null;
  previewAudienceKey.value = '';
});

onMounted(load);
</script>
