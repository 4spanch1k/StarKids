<template>
  <PageShell eyebrow="Коммуникации" title="Пуш-кампании" description="Ручные сообщения пользователям. Аудитория фиксируется в момент отправки.">
    <p v-if="error" class="admin-inline-message admin-inline-message--error">{{ error }}</p>
    <p v-if="!providerConfigured" class="admin-inline-message">FCM не настроен: кампании можно подготовить, но реальная отправка недоступна.</p>
    <form class="admin-list-record" @submit.prevent="create">
      <input v-model="form.internal_name" class="admin-control" placeholder="Внутреннее название" required />
      <input v-model="form.title" class="admin-control" placeholder="Заголовок" maxlength="100" required />
      <textarea v-model="form.body" class="admin-control" placeholder="Текст сообщения" maxlength="500" required />
      <select v-model="form.audience.type" class="admin-control"><option value="all_users">Все пользователи</option><option value="birthday_in_days">День рождения через N дней</option><option value="visit_segment">По посещениям</option></select>
      <input v-if="form.audience.type === 'birthday_in_days'" v-model.number="form.audience.days_before_birthday" class="admin-control" type="number" min="1" max="365" placeholder="N дней" required />
      <select v-if="form.audience.type === 'visit_segment'" v-model="form.audience.visit_segment" class="admin-control" required>
        <option value="never_visited">Ещё не посещали</option>
        <option value="first_visit_only">Были 1 раз</option>
        <option value="returning">Возвращались</option>
        <option value="dormant_30">Не были 30+ дней</option>
        <option value="dormant_60">Не были 60+ дней</option>
        <option value="dormant_90">Не были 90+ дней</option>
      </select>
      <select v-model="form.destination" class="admin-control"><option value="home">Главная</option><option value="tickets">Билеты</option><option value="birthdays">Праздники</option><option value="promotions">Акции</option><option value="profile">Профиль</option></select>
      <label class="admin-field"><span>Запланировать (необязательно)</span><input v-model="form.scheduled_at" class="admin-control" type="datetime-local" /></label>
      <div class="admin-page-actions"><button class="admin-button admin-button--secondary" type="button" @click="preview">Проверить аудиторию</button><button class="admin-button admin-button--primary" type="submit" :disabled="saving">{{ saving ? 'Сохраняем…' : form.scheduled_at ? 'Запланировать' : 'Создать черновик' }}</button></div>
      <p v-if="previewResult" class="admin-inline-message">Аудитория: {{ previewResult.targeted_users }} пользователей, {{ previewResult.targeted_devices }} устройств.</p>
    </form>
    <StatePanel v-if="loading" title="Загружаем кампании" />
    <div v-else class="admin-list-records">
      <article v-for="campaign in campaigns" :key="campaign.id" class="admin-list-record">
        <div class="admin-list-record__copy"><strong>{{ campaign.internal_name }}</strong><span>{{ campaign.title }} · {{ audienceLabel(campaign) }}</span><span>Статус: {{ campaign.status }} · {{ campaign.sent_count }}/{{ campaign.targeted_devices }} отправлено</span>
          <small v-if="attributions[campaign.id]">Отправлено семьям: {{ attributions[campaign.id].sent_users }} · Открыли: {{ attributions[campaign.id].opened_users }}<template v-if="attributions[campaign.id].open_rate !== null"> ({{ formatRate(attributions[campaign.id].open_rate) }}%)</template></small>
          <small v-if="attributions[campaign.id]">Last-touch, 7 дней: посещения {{ attributions[campaign.id].attributed_visit_users }} семей / {{ attributions[campaign.id].attributed_visits }} визитов · Birthday leads {{ attributions[campaign.id].attributed_birthday_leads }}</small>
          <small v-else-if="attributionLoading" class="admin-muted">Загружаем атрибуцию…</small>
          <small v-else-if="attributionError" class="admin-inline-message--error">Атрибуция недоступна</small>
        </div>
        <div class="admin-page-actions"><button v-if="campaign.status === 'draft' || campaign.status === 'scheduled'" class="admin-button admin-button--primary" type="button" :disabled="sendingId === campaign.id" @click="send(campaign.id)">{{ sendingId === campaign.id ? 'Отправляем…' : 'Отправить' }}</button><button v-if="campaign.status === 'draft' || campaign.status === 'scheduled'" class="admin-button admin-button--secondary" type="button" :disabled="sendingId === campaign.id" @click="cancel(campaign.id)">Отменить</button></div>
      </article>
      <StatePanel v-if="campaigns.length === 0" title="Кампаний пока нет" description="Создайте первое сообщение для аудитории." />
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import { cancelPushCampaign, createPushCampaign, fetchPushCampaignAttribution, listPushCampaigns, previewPushAudience, sendPushCampaign, type CampaignAudience, type PushCampaign, type PushCampaignAttribution, type VisitAudienceSegment } from '@/features/push-campaigns/api/pushCampaignsApi';

const campaigns = ref<PushCampaign[]>([]); const attributions = reactive<Record<string, PushCampaignAttribution>>({}); const loading = ref(true); const attributionLoading = ref(false); const attributionError = ref(false); const saving = ref(false); const sendingId = ref<string | null>(null); const error = ref(''); const providerConfigured = ref(true); const previewResult = ref<{ targeted_users: number; targeted_devices: number } | null>(null);
const form = reactive({ internal_name: '', title: '', body: '', audience: { type: 'all_users' as 'all_users' | 'birthday_in_days' | 'visit_segment', days_before_birthday: 7, visit_segment: 'dormant_30' as VisitAudienceSegment }, destination: 'home' as PushCampaign['destination'], scheduled_at: '' });
async function load() { loading.value = true; attributionLoading.value = true; attributionError.value = false; try { campaigns.value = await listPushCampaigns(); providerConfigured.value = campaigns.value.every((c) => c.push_provider_configured); const reports = await Promise.all(campaigns.value.map(async (campaign) => [campaign.id, await fetchPushCampaignAttribution(campaign.id)] as const)); Object.keys(attributions).forEach((id) => delete attributions[id]); reports.forEach(([id, report]) => { attributions[id] = report; }); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось загрузить кампании'; attributionError.value = true; } finally { loading.value = false; attributionLoading.value = false; } }
function currentAudience(): CampaignAudience {
  if (form.audience.type === 'birthday_in_days') return { type: 'birthday_in_days', days_before_birthday: form.audience.days_before_birthday };
  if (form.audience.type === 'visit_segment') return { type: 'visit_segment', visit_segment: form.audience.visit_segment };
  return { type: 'all_users' };
}
async function preview() { try { previewResult.value = await previewPushAudience(currentAudience()); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось проверить аудиторию'; } }
async function create() { saving.value = true; error.value = ''; try { await createPushCampaign({ ...form, scheduled_at: form.scheduled_at ? new Date(form.scheduled_at).toISOString() : null, audience: currentAudience() }); Object.assign(form, { internal_name: '', title: '', body: '', scheduled_at: '' }); await load(); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось создать кампанию'; } finally { saving.value = false; } }
async function send(id: string) { if (sendingId.value || !window.confirm('Отправить кампанию сейчас?')) return; sendingId.value = id; error.value = ''; try { await sendPushCampaign(id); await load(); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось отправить кампанию'; } finally { sendingId.value = null; } }
async function cancel(id: string) { try { await cancelPushCampaign(id); await load(); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось отменить кампанию'; } }
function audienceLabel(c: PushCampaign) {
  if (c.audience.type === 'all_users') return 'все пользователи';
  if (c.audience.type === 'birthday_in_days') return `дни рождения через ${c.audience.days_before_birthday} дн.`;
  if (c.audience.type === 'visit_segment') return `по посещениям: ${segmentLabel(c.audience.visit_segment)}`;
  return 'один пользователь';
}
function segmentLabel(segment: VisitAudienceSegment) { return ({ never_visited: 'ещё не посещали', first_visit_only: 'были 1 раз', returning: 'возвращались', dormant_30: 'не были 30+ дней', dormant_60: 'не были 60+ дней', dormant_90: 'не были 90+ дней' } as Record<VisitAudienceSegment, string>)[segment]; }
function formatRate(value: number | null) { return value === null ? '—' : (value * 100).toFixed(1); }
onMounted(load);
</script>
