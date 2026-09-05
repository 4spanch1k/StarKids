<template>
  <PageShell eyebrow="Финансовые настройки" title="Лояльность" description="Правила выключены по умолчанию. Изменение правил влияет на новые события после публикации.">
    <p v-if="saveError" class="admin-inline-message admin-inline-message--error">{{ saveError }}</p>
    <div class="admin-section-heading"><h2>Экономика списания</h2></div>
    <form class="admin-list-record" @submit.prevent="saveSettings">
      <label class="admin-field"><span>Максимум списания, %</span><input v-model="settings.maxRedemptionPercent" class="admin-control" type="number" min="0" max="100" step="0.01" /></label>
      <p class="admin-inline-message">1 бонус всегда равен 1 ₸ и не может быть изменён.</p>
      <button class="admin-button admin-button--secondary" type="submit" :disabled="savingSettings">{{ savingSettings ? 'Сохраняем…' : 'Сохранить лимит' }}</button>
    </form>
    <div class="admin-section-heading"><h2>Правила начисления</h2><button class="admin-button admin-button--primary" type="button" @click="addRule">Добавить правило</button></div>
    <StatePanel v-if="loading" title="Загружаем правила" description="Проверяем текущую конфигурацию бонусов." />
    <StatePanel v-else-if="error" title="Не удалось загрузить правила" :description="error" tone="error"><template #actions><button class="admin-button admin-button--secondary" type="button" @click="load">Повторить</button></template></StatePanel>
    <div v-else class="admin-list-records">
      <form v-for="rule in rules" :key="rule.id" class="admin-list-record" @submit.prevent="save(rule)">
        <div class="admin-list-record__copy">
          <strong>{{ eventLabels[rule.eventType] ?? rule.eventType }}</strong>
          <span>Период: {{ rule.startsAt ? formatDate(rule.startsAt) : 'сейчас' }} — {{ rule.endsAt ? formatDate(rule.endsAt) : 'без окончания' }}</span>
        </div>
        <select v-model="rule.rewardType" class="admin-control" aria-label="Тип награды"><option value="fixed">Фиксированные бонусы</option><option value="percent">Процент от оплаты</option></select>
        <input v-model="rule.value" class="admin-control loyalty-rule__value" type="number" min="0" :max="rule.rewardType === 'percent' ? 100 : undefined" step="0.01" aria-label="Значение правила" />
        <label class="admin-switch"><input v-model="rule.isActive" type="checkbox" /><span>Активно</span></label>
        <button class="admin-button admin-button--secondary" type="submit" :disabled="savingId === rule.id">{{ savingId === rule.id ? 'Сохраняем…' : 'Сохранить' }}</button>
      </form>
      <p v-if="rules.length === 0" class="admin-inline-message">Правил пока нет. При пустой конфигурации бонусы не начисляются.</p>
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import { createLoyaltyRule, getLoyaltySettings, listLoyaltyRules, updateLoyaltyRule, updateLoyaltySettings, type LoyaltyRule } from '@/features/loyalty/api/loyaltyRulesApi';

const rules = ref<LoyaltyRule[]>([]); const loading = ref(true); const error = ref(''); const saveError = ref(''); const savingId = ref(''); const savingSettings = ref(false); const settings = ref({ maxRedemptionPercent: '0' });
const eventLabels: Record<string, string> = { registration: 'Регистрация', ticket_purchase: 'Покупка билета', birthday_purchase: 'Покупка праздника', restaurant_purchase: 'Покупка в кафе' };
async function load() { loading.value = true; error.value = ''; try { const [loadedRules, loadedSettings] = await Promise.all([listLoyaltyRules(), getLoyaltySettings()]); rules.value = loadedRules; settings.value = { maxRedemptionPercent: loadedSettings.maxRedemptionPercent }; } catch (e) { error.value = e instanceof Error ? e.message : 'Ошибка загрузки'; } finally { loading.value = false; } }
async function saveSettings() { savingSettings.value = true; saveError.value = ''; try { const updated = await updateLoyaltySettings(settings.value); settings.value = { maxRedemptionPercent: updated.maxRedemptionPercent }; } catch (e) { saveError.value = e instanceof Error ? e.message : 'Не удалось сохранить лимит'; } finally { savingSettings.value = false; } }
async function addRule() { saveError.value = ''; try { const rule = await createLoyaltyRule({ eventType: 'ticket_purchase', rewardType: 'percent', value: '0', isActive: false, startsAt: null, endsAt: null }); rules.value.unshift(rule); } catch (e) { saveError.value = e instanceof Error ? e.message : 'Не удалось создать правило'; } }
async function save(rule: LoyaltyRule) { savingId.value = rule.id; saveError.value = ''; try { const updated = await updateLoyaltyRule(rule.id, { eventType: rule.eventType, rewardType: rule.rewardType, value: rule.value, isActive: rule.isActive, startsAt: rule.startsAt, endsAt: rule.endsAt }); Object.assign(rule, updated); } catch (e) { saveError.value = e instanceof Error ? e.message : 'Не удалось сохранить правило'; } finally { savingId.value = ''; } }
function formatDate(value: string) { return new Date(value).toLocaleDateString('ru-RU'); }
onMounted(load);
</script>
