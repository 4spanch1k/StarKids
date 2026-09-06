<template>
  <PageShell eyebrow="Коммуникации" title="Пуш-кампании" description="Ручные сообщения пользователям. Аудитория фиксируется в момент отправки.">
    <p v-if="error" class="admin-inline-message admin-inline-message--error">{{ error }}</p>
    <p v-if="!providerConfigured" class="admin-inline-message">FCM не настроен: кампании можно подготовить, но реальная отправка недоступна.</p>
    <form class="admin-list-record" @submit.prevent="create">
      <input v-model="form.internal_name" class="admin-control" placeholder="Внутреннее название" required />
      <input v-model="form.title" class="admin-control" placeholder="Заголовок" maxlength="100" required />
      <textarea v-model="form.body" class="admin-control" placeholder="Текст сообщения" maxlength="500" required />
      <select v-model="form.audience.type" class="admin-control"><option value="all_users">Все пользователи</option><option value="birthday_in_days">День рождения через N дней</option></select>
      <input v-if="form.audience.type === 'birthday_in_days'" v-model.number="form.audience.days_before_birthday" class="admin-control" type="number" min="1" max="365" placeholder="N дней" required />
      <select v-model="form.destination" class="admin-control"><option value="home">Главная</option><option value="tickets">Билеты</option><option value="birthdays">Праздники</option><option value="promotions">Акции</option><option value="profile">Профиль</option></select>
      <label class="admin-field"><span>Запланировать (необязательно)</span><input v-model="form.scheduled_at" class="admin-control" type="datetime-local" /></label>
      <div class="admin-page-actions"><button class="admin-button admin-button--secondary" type="button" @click="preview">Проверить аудиторию</button><button class="admin-button admin-button--primary" type="submit" :disabled="saving">{{ saving ? 'Сохраняем…' : form.scheduled_at ? 'Запланировать' : 'Создать черновик' }}</button></div>
      <p v-if="previewResult" class="admin-inline-message">Аудитория: {{ previewResult.targeted_users }} пользователей, {{ previewResult.targeted_devices }} устройств.</p>
    </form>
    <StatePanel v-if="loading" title="Загружаем кампании" />
    <div v-else class="admin-list-records">
      <article v-for="campaign in campaigns" :key="campaign.id" class="admin-list-record">
        <div class="admin-list-record__copy"><strong>{{ campaign.internal_name }}</strong><span>{{ campaign.title }} · {{ audienceLabel(campaign) }}</span><span>Статус: {{ campaign.status }} · {{ campaign.sent_count }}/{{ campaign.targeted_devices }} отправлено</span></div>
        <div class="admin-page-actions"><button v-if="campaign.status === 'draft' || campaign.status === 'scheduled'" class="admin-button admin-button--primary" type="button" @click="send(campaign.id)">Отправить</button><button v-if="campaign.status === 'draft' || campaign.status === 'scheduled'" class="admin-button admin-button--secondary" type="button" @click="cancel(campaign.id)">Отменить</button></div>
      </article>
      <StatePanel v-if="campaigns.length === 0" title="Кампаний пока нет" description="Создайте первое сообщение для аудитории." />
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import { cancelPushCampaign, createPushCampaign, listPushCampaigns, previewPushAudience, sendPushCampaign, type PushCampaign } from '@/features/push-campaigns/api/pushCampaignsApi';

const campaigns = ref<PushCampaign[]>([]); const loading = ref(true); const saving = ref(false); const error = ref(''); const providerConfigured = ref(true); const previewResult = ref<{ targeted_users: number; targeted_devices: number } | null>(null);
const form = reactive({ internal_name: '', title: '', body: '', audience: { type: 'all_users' as 'all_users' | 'birthday_in_days', days_before_birthday: 7 }, destination: 'home' as PushCampaign['destination'], scheduled_at: '' });
async function load() { loading.value = true; try { campaigns.value = await listPushCampaigns(); providerConfigured.value = campaigns.value.every((c) => c.push_provider_configured); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось загрузить кампании'; } finally { loading.value = false; } }
async function preview() { try { previewResult.value = await previewPushAudience(form.audience); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось проверить аудиторию'; } }
async function create() { saving.value = true; error.value = ''; try { await createPushCampaign({ ...form, scheduled_at: form.scheduled_at ? new Date(form.scheduled_at).toISOString() : null, audience: { ...form.audience, ...(form.audience.type === 'all_users' ? {} : { days_before_birthday: form.audience.days_before_birthday }) } }); Object.assign(form, { internal_name: '', title: '', body: '', scheduled_at: '' }); await load(); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось создать кампанию'; } finally { saving.value = false; } }
async function send(id: string) { if (!window.confirm('Отправить кампанию сейчас?')) return; try { await sendPushCampaign(id); await load(); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось отправить кампанию'; } }
async function cancel(id: string) { try { await cancelPushCampaign(id); await load(); } catch (e) { error.value = e instanceof Error ? e.message : 'Не удалось отменить кампанию'; } }
function audienceLabel(c: PushCampaign) { return c.audience.type === 'all_users' ? 'все пользователи' : `дни рождения через ${c.audience.days_before_birthday} дн.`; }
onMounted(load);
</script>
