<template>
  <AdminCrudWorkspace
    eyebrow="Коммерческие условия"
    title="Тарифы и правила"
    description="Цены посещения и правила по филиалам."
    :show-detail="showInlineDetail"
    :route-panel-open="isRoutePanelOpen"
    :route-panel-title="routePanelTitle"
    :route-panel-eyebrow="routePanelEyebrow"
    :route-panel-variant="routePanelVariant"
    :route-panel-close-label="routePanelCloseLabel"
    @back="handlePanelClose"
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--secondary"
        @click="pricesRulesManager.initialize"
      >
        Обновить филиалы
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Филиалы</h2>
      </div>

      <AdminCompactFilters>
        <template #primary>
          <AdminSearchField
            v-model="searchQuery"
            placeholder="Найти филиал"
          />
        </template>
      </AdminCompactFilters>

      <StatePanel
        v-if="pricesRulesManager.isBranchesLoading"
        title="Загружаем филиалы"
        description="Подготавливаем список филиалов для настройки тарифов."
      />

      <StatePanel
        v-else-if="pricesRulesManager.branchesErrorMessage"
        title="Не удалось загрузить филиалы"
        :description="pricesRulesManager.branchesErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="pricesRulesManager.initialize"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <StatePanel
        v-else-if="filteredBranches.length === 0"
        title="Филиалы не найдены"
        description="Измените поисковый запрос, чтобы снова увидеть список."
      />

      <div v-else class="admin-list-records">
        <button
          v-for="branch in filteredBranches"
          :key="branch.id"
          type="button"
          class="admin-list-record"
          :class="{
            'admin-list-record--active': branch.id === pricesRulesManager.selectedBranchId,
          }"
          @click="void routeState.goToDetail(branch.id)"
        >
          <span class="admin-list-record__accent" aria-hidden="true"></span>
          <div class="admin-list-record__copy">
            <strong>{{ branch.name }}</strong>
            <p>{{ branch.city }} · {{ branch.shortLabel }}</p>
            <span>{{ branch.workingHours }}</span>
          </div>
          <StatusBadge
            :label="resolveActiveStatus(branch.isActive).label"
            :tone="resolveActiveStatus(branch.isActive).tone"
          />
        </button>
      </div>
    </template>

    <template #detail>
      <StatePanel
        v-if="pricesRulesManager.isContentLoading"
        title="Открываем тарифы и правила"
        description="Подтягиваем текущий профиль выбранного филиала."
      />

      <StatePanel
        v-else-if="pricesRulesManager.contentErrorMessage && routeMode === 'detail'"
        title="Не удалось открыть тарифы и правила"
        :description="pricesRulesManager.contentErrorMessage"
        tone="error"
      />

      <template v-else-if="selectedBranch">
        <template v-if="routeMode === 'detail'">
          <div class="tariffs-detail-view">
            <header class="admin-detail-header">
              <div class="admin-detail-header__copy">
                <p class="admin-detail-header__eyebrow">Код: {{ selectedBranch.id }}</p>
                <div class="admin-detail-header__title-row">
                  <h2>{{ selectedBranch.name }}</h2>
                  <StatusBadge
                    :label="resolveActiveStatus(selectedBranch.isActive).label"
                    :tone="resolveActiveStatus(selectedBranch.isActive).tone"
                  />
                </div>
                <p class="admin-detail-header__summary">
                  {{ selectedBranch.city }} · {{ selectedBranch.shortLabel }}
                </p>
              </div>

              <div class="tariffs-detail-view__actions">
                <button
                  type="button"
                  class="admin-button admin-button--primary"
                  @click="void routeState.goToEdit(selectedBranch.id)"
                >
                  Редактировать
                </button>
              </div>
            </header>

            <StatePanel
              v-if="!pricesRulesManager.hasExistingProfile"
              title="Профиль цен еще не создан"
              description="Заполните поля ниже и сохраните. Первый профиль для этого филиала будет создан автоматически."
            />

            <AdminSummaryList
              title="Верхний блок"
              :items="tariffsHeaderItems"
            />

            <AdminSummaryList
              title="Тарифы посещения"
              :items="tariffsCountItems"
            >
              <ul class="tariffs-detail-view__list">
                <li
                  v-for="(tariff, index) in pricesRulesManager.form.visitTariffs"
                  :key="`detail-tariff-${index}`"
                >
                  <strong>{{ tariff.title || `Тариф ${index + 1}` }}</strong>
                  <span> · {{ tariff.priceLabel || 'Без подписи цены' }}</span>
                </li>
              </ul>
            </AdminSummaryList>

            <AdminSummaryList
              title="Правила посещения"
              :items="rulesCountItems"
            >
              <ul class="tariffs-detail-view__list">
                <li
                  v-for="(rule, index) in pricesRulesManager.form.rules"
                  :key="`detail-rule-${index}`"
                >
                  {{ rule.text || `Правило ${index + 1}` }}
                </li>
              </ul>
            </AdminSummaryList>
          </div>
        </template>

        <form
          v-else
          class="admin-form-stack"
          @submit.prevent="handleSave"
        >
          <div class="admin-section-heading">
            <h2>Редактировать тарифы и правила</h2>
          </div>

          <div class="admin-form-grid--two">
            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Заголовок</span>
              <input
                v-model="pricesRulesManager.form.introTitle"
                class="admin-control"
              />
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="pricesRulesManager.form.introDescription"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Блок про день рождения</span>
              <textarea
                v-model="pricesRulesManager.form.birthdayNote"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Дисклеймер</span>
              <textarea
                v-model="pricesRulesManager.form.disclaimer"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>
          </div>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Тарифы посещения</h3>
              <p>Каждая карточка — отдельный тариф для экрана цен в мобильном приложении.</p>
            </div>

            <div class="admin-repeater">
              <article
                v-for="(tariff, index) in pricesRulesManager.form.visitTariffs"
                :key="`tariff-${index}`"
                class="admin-repeater__item"
              >
                <div class="admin-repeater__header">
                  <strong>Тариф {{ index + 1 }}</strong>
                  <button
                    type="button"
                    class="admin-button admin-button--ghost"
                    @click="pricesRulesManager.removeTariff(index)"
                  >
                    Удалить
                  </button>
                </div>

                <div class="admin-repeater__grid">
                  <label class="admin-field">
                    <span class="admin-field__label">Название</span>
                    <input v-model="tariff.title" class="admin-control" />
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Подпись цены</span>
                    <input v-model="tariff.priceLabel" class="admin-control" />
                  </label>

                  <label class="admin-field admin-field--full">
                    <span class="admin-field__label">Описание</span>
                    <textarea
                      v-model="tariff.description"
                      class="admin-control admin-control--textarea"
                    ></textarea>
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Порядок</span>
                    <input
                      v-model.number="tariff.displayOrder"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>
                </div>

                <AdminSwitchField
                  v-model="tariff.isActive"
                  label="Тариф активен"
                  hint="Неактивный тариф не будет показан в приложении."
                />
              </article>
            </div>

            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="pricesRulesManager.addTariff"
            >
              Добавить тариф
            </button>
          </section>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Правила посещения</h3>
              <p>Управляйте отдельными правилами без правок в коде приложения.</p>
            </div>

            <div class="admin-repeater">
              <article
                v-for="(rule, index) in pricesRulesManager.form.rules"
                :key="`rule-${index}`"
                class="admin-repeater__item"
              >
                <div class="admin-repeater__header">
                  <strong>Правило {{ index + 1 }}</strong>
                  <button
                    type="button"
                    class="admin-button admin-button--ghost"
                    @click="pricesRulesManager.removeRule(index)"
                  >
                    Удалить
                  </button>
                </div>

                <div class="admin-repeater__grid">
                  <label class="admin-field admin-field--full">
                    <span class="admin-field__label">Текст правила</span>
                    <textarea
                      v-model="rule.text"
                      class="admin-control admin-control--textarea"
                    ></textarea>
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Порядок</span>
                    <input
                      v-model.number="rule.displayOrder"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>
                </div>

                <AdminSwitchField
                  v-model="rule.isActive"
                  label="Правило активно"
                  hint="Неактивное правило остается в админке, но не показывается клиенту."
                />
              </article>
            </div>

            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="pricesRulesManager.addRule"
            >
              Добавить правило
            </button>
          </section>

          <p
            v-if="pricesRulesManager.successMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ pricesRulesManager.successMessage }}
          </p>
          <p
            v-if="pricesRulesManager.contentErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ pricesRulesManager.contentErrorMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="pricesRulesManager.isSaving"
            >
              {{ pricesRulesManager.isSaving ? 'Сохраняем…' : 'Сохранить тарифы и правила' }}
            </button>
            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="void handlePanelClose()"
            >
              Закрыть
            </button>
          </AdminStickyActions>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите филиал"
        description="Откройте филиал, чтобы посмотреть или изменить тарифы и правила."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import { useBranchPricesRulesManager } from '@/features/branches/model/useBranchPricesRulesManager';
import { resolveActiveStatus } from '@/shared/lib/adminStatus';
import { useAdminCrudRouteState } from '@/shared/composables/useAdminCrudRouteState';
import { useFormSnapshotDirty } from '@/shared/composables/useFormSnapshotDirty';
import { useUnsavedChangesGuard } from '@/shared/composables/useUnsavedChangesGuard';
import AdminCompactFilters from '@/shared/ui/AdminCompactFilters.vue';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminStickyActions from '@/shared/ui/AdminStickyActions.vue';
import AdminSummaryList from '@/shared/ui/AdminSummaryList.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const pricesRulesManager = reactive(useBranchPricesRulesManager());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.tariffs.list,
  detailRouteName: adminCrudRouteNames.tariffs.detail,
  editRouteName: adminCrudRouteNames.tariffs.edit,
  idParam: adminCrudRouteNames.tariffs.idParam,
});

const searchQuery = ref('');

const editDirty = useFormSnapshotDirty(() => {
  return {
    introTitle: pricesRulesManager.form.introTitle,
    introDescription: pricesRulesManager.form.introDescription,
    birthdayNote: pricesRulesManager.form.birthdayNote,
    disclaimer: pricesRulesManager.form.disclaimer,
    visitTariffs: pricesRulesManager.form.visitTariffs.map((tariff) => ({ ...tariff })),
    rules: pricesRulesManager.form.rules.map((rule) => ({ ...rule })),
  };
});

const { confirmLeave } = useUnsavedChangesGuard(() => {
  return routeMode.value === 'edit' && editDirty.isDirty.value;
});

const routeMode = computed(() => routeState.mode.value);

const showInlineDetail = computed(() => {
  return routeState.isDesktop.value && routeMode.value === 'detail' && Boolean(selectedBranch.value);
});

const isRoutePanelOpen = computed(() => {
  return routeState.showDetailRoutePanel.value || routeMode.value === 'edit';
});

const routePanelTitle = computed(() => {
  if (routeMode.value === 'edit') {
    return selectedBranch.value?.name || 'Редактировать тарифы и правила';
  }

  return selectedBranch.value?.name || 'Карточка филиала';
});

const routePanelEyebrow = computed(() => {
  return routeMode.value === 'detail' ? 'Карточка тарифов' : 'Редактирование';
});

const routePanelVariant = computed<'detail' | 'form'>(() => {
  return routeMode.value === 'detail' ? 'detail' : 'form';
});

const routePanelCloseLabel = computed(() => {
  return routeMode.value === 'detail' ? 'К списку' : 'Закрыть';
});

const filteredBranches = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) {
    return pricesRulesManager.branchOptions;
  }

  return pricesRulesManager.branchOptions.filter((branch) => {
    return `${branch.name} ${branch.city} ${branch.shortLabel}`
      .toLowerCase()
      .includes(query);
  });
});

const selectedBranch = computed(() => {
  return pricesRulesManager.branchOptions.find((branch) => {
    return branch.id === pricesRulesManager.selectedBranchId;
  }) ?? null;
});

const tariffsHeaderItems = computed(() => {
  return [
    { label: 'Заголовок', value: pricesRulesManager.form.introTitle || 'Не задан' },
    {
      label: 'Описание',
      value: pricesRulesManager.form.introDescription || 'Не задано',
      fullWidth: true,
    },
    {
      label: 'Блок про день рождения',
      value: pricesRulesManager.form.birthdayNote || 'Не задан',
      fullWidth: true,
    },
    {
      label: 'Дисклеймер',
      value: pricesRulesManager.form.disclaimer || 'Не задан',
      fullWidth: true,
    },
  ];
});

const tariffsCountItems = computed(() => {
  return [{ label: 'Количество тарифов', value: String(pricesRulesManager.form.visitTariffs.length) }];
});

const rulesCountItems = computed(() => {
  return [{ label: 'Количество правил', value: String(pricesRulesManager.form.rules.length) }];
});

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, branchId]) => {
    if ((mode === 'detail' || mode === 'edit') && branchId) {
      if (pricesRulesManager.selectedBranchId !== branchId) {
        await pricesRulesManager.selectBranch(branchId);
      }
      await nextTick();
      editDirty.markClean();
    }
  },
  { immediate: true },
);

onMounted(() => {
  void pricesRulesManager.initialize();
});

async function handlePanelClose() {
  if (routeMode.value === 'edit' && !confirmLeave()) {
    return;
  }

  if (routeMode.value === 'detail') {
    await routeState.closeDetail();
    return;
  }

  await routeState.closeEditor();
}

async function handleSave() {
  await pricesRulesManager.save();

  if (!pricesRulesManager.contentErrorMessage) {
    editDirty.markClean();
    await routeState.goToDetail(pricesRulesManager.selectedBranchId);
  }
}
</script>

<style scoped>
.tariffs-detail-view {
  display: grid;
  gap: 12px;
}

.tariffs-detail-view__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.tariffs-detail-view__list {
  display: grid;
  gap: 8px;
  margin: 0;
  padding-left: 18px;
}
</style>
