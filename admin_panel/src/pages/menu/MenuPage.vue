<template>
  <AdminCrudWorkspace
    eyebrow="Управляемый контент"
    title="Меню"
    description="Категории и блюда по филиалам."
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
        @click="menuManager.initialize"
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
        v-if="menuManager.isBranchesLoading"
        title="Загружаем филиалы"
        description="Подготавливаем список филиалов для настройки меню."
      />

      <StatePanel
        v-else-if="menuManager.branchesErrorMessage"
        title="Не удалось загрузить филиалы"
        :description="menuManager.branchesErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="menuManager.initialize"
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
          :class="{ 'admin-list-record--active': branch.id === menuManager.selectedBranchId }"
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
        v-if="menuManager.isContentLoading"
        title="Открываем меню"
        description="Подтягиваем категории и позиции выбранного филиала."
      />

      <StatePanel
        v-else-if="menuManager.contentErrorMessage && routeMode === 'detail'"
        title="Не удалось открыть меню"
        :description="menuManager.contentErrorMessage"
        tone="error"
      />

      <template v-else-if="selectedBranch">
        <template v-if="routeMode === 'detail'">
          <div class="menu-detail-view">
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

              <div class="menu-detail-view__actions">
                <button
                  type="button"
                  class="admin-button admin-button--primary"
                  @click="void routeState.goToEdit(selectedBranch.id)"
                >
                  Редактировать
                </button>
              </div>
            </header>

            <AdminSummaryList
              title="Сводка меню"
              :items="menuSummaryItems"
            />

            <AdminSummaryList
              title="Категории"
              :items="categorySummaryItems"
            >
              <ul class="menu-detail-view__list">
                <li
                  v-for="category in sortedCategories"
                  :key="`detail-category-${category.key}`"
                >
                  <strong>{{ category.title || 'Без названия' }}</strong>
                  <span> · порядок {{ category.displayOrder }}</span>
                </li>
              </ul>
            </AdminSummaryList>

            <AdminSummaryList
              title="Позиции меню"
              :items="itemSummaryItems"
            >
              <ul class="menu-detail-view__list">
                <li
                  v-for="(item, index) in sortedItems"
                  :key="`detail-item-${item.id || index}`"
                >
                  <strong>{{ item.title || `Позиция ${index + 1}` }}</strong>
                  <span> · {{ resolveCategoryTitle(item.categoryKey) }}</span>
                  <span> · {{ formatPrice(item.priceTenge) }}</span>
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
            <h2>Редактировать меню</h2>
          </div>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Категории</h3>
              <p>Категории управляют структурой меню и порядком блоков в мобильном приложении.</p>
            </div>

            <div class="admin-repeater">
              <article
                v-for="(category, index) in menuManager.form.categories"
                :key="category.key"
                class="admin-repeater__item"
              >
                <div class="admin-repeater__header">
                  <strong>{{ category.title || `Категория ${index + 1}` }}</strong>
                  <button
                    type="button"
                    class="admin-button admin-button--ghost"
                    @click="menuManager.removeCategory(index)"
                  >
                    Удалить
                  </button>
                </div>

                <div class="admin-repeater__grid">
                  <label class="admin-field">
                    <span class="admin-field__label">Название категории</span>
                    <input
                      v-model="category.title"
                      class="admin-control"
                    />
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Порядок</span>
                    <input
                      v-model.number="category.displayOrder"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>
                </div>

                <AdminSwitchField
                  v-model="category.isActive"
                  label="Категория активна"
                  hint="Неактивная категория не будет показана в мобильном приложении."
                />
              </article>
            </div>

            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="menuManager.addCategory"
            >
              Добавить категорию
            </button>
          </section>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Позиции меню</h3>
              <p>Для каждого блюда хранится отдельная картинка, цена, категория и порядок.</p>
            </div>

            <div class="admin-repeater">
              <article
                v-for="(item, index) in menuManager.form.items"
                :key="item.id || `item-${index}`"
                class="admin-repeater__item"
              >
                <div class="admin-repeater__header">
                  <strong>{{ item.title || `Позиция ${index + 1}` }}</strong>
                  <button
                    type="button"
                    class="admin-button admin-button--ghost"
                    @click="menuManager.removeItem(index)"
                  >
                    Удалить
                  </button>
                </div>

                <div class="admin-repeater__grid">
                  <label class="admin-field">
                    <span class="admin-field__label">Название блюда</span>
                    <input
                      v-model="item.title"
                      class="admin-control"
                    />
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Цена, тг</span>
                    <input
                      v-model.number="item.priceTenge"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Категория</span>
                    <select
                      v-model="item.categoryKey"
                      class="admin-control"
                    >
                      <option
                        v-for="category in sortedCategories"
                        :key="`option-${category.key}`"
                        :value="category.key"
                      >
                        {{ category.title || 'Без названия' }}
                      </option>
                    </select>
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Порядок</span>
                    <input
                      v-model.number="item.displayOrder"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>

                  <label class="admin-field admin-field--full">
                    <span class="admin-field__label">Ссылка на картинку</span>
                    <input
                      v-model="item.imageUrl"
                      class="admin-control"
                      placeholder="https://..."
                    />
                  </label>
                </div>

                <div
                  v-if="item.imageUrl"
                  class="menu-editor__preview"
                >
                  <img
                    :src="item.imageUrl"
                    :alt="item.title || 'Фото блюда'"
                  >
                </div>

                <AdminSwitchField
                  v-model="item.isActive"
                  label="Позиция активна"
                  hint="Скрытая позиция останется в админке, но пропадет из мобильного приложения."
                />
              </article>
            </div>

            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="menuManager.addItem"
            >
              Добавить блюдо
            </button>
          </section>

          <p
            v-if="menuManager.successMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ menuManager.successMessage }}
          </p>
          <p
            v-if="menuManager.contentErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ menuManager.contentErrorMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="menuManager.isSaving"
            >
              {{ menuManager.isSaving ? 'Сохраняем…' : 'Сохранить меню' }}
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
        description="Откройте филиал, чтобы посмотреть или изменить меню."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import { useBranchMenuManager } from '@/features/branches/model/useBranchMenuManager';
import type {
  AdminBranchMenuCategory,
  AdminBranchMenuItem,
} from '@/features/branches/model/adminBranch';
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

const menuManager = reactive(useBranchMenuManager());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.menu.list,
  detailRouteName: adminCrudRouteNames.menu.detail,
  editRouteName: adminCrudRouteNames.menu.edit,
  idParam: adminCrudRouteNames.menu.idParam,
});

const searchQuery = ref('');

const editDirty = useFormSnapshotDirty(() => {
  return {
    categories: menuManager.form.categories.map((category) => ({ ...category })),
    items: menuManager.form.items.map((item) => ({ ...item })),
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
    return selectedBranch.value?.name || 'Редактировать меню';
  }

  return selectedBranch.value?.name || 'Карточка филиала';
});

const routePanelEyebrow = computed(() => {
  return routeMode.value === 'detail' ? 'Карточка меню' : 'Редактирование';
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
    return menuManager.branchOptions;
  }

  return menuManager.branchOptions.filter((branch) => {
    return `${branch.name} ${branch.city} ${branch.shortLabel}`
      .toLowerCase()
      .includes(query);
  });
});

const selectedBranch = computed(() => {
  return menuManager.branchOptions.find((branch) => {
    return branch.id === menuManager.selectedBranchId;
  }) ?? null;
});

const sortedCategories = computed<AdminBranchMenuCategory[]>(() => {
  return [...menuManager.form.categories].sort((left, right) => {
    return left.displayOrder - right.displayOrder;
  });
});

const sortedItems = computed<AdminBranchMenuItem[]>(() => {
  return [...menuManager.form.items].sort((left, right) => {
    if (left.displayOrder !== right.displayOrder) {
      return left.displayOrder - right.displayOrder;
    }
    return left.title.localeCompare(right.title);
  });
});

const menuSummaryItems = computed(() => {
  return [
    { label: 'Категорий', value: String(menuManager.form.categories.length) },
    { label: 'Позиций', value: String(menuManager.form.items.length) },
    {
      label: 'Активных позиций',
      value: String(menuManager.form.items.filter((item) => item.isActive).length),
    },
  ];
});

const categorySummaryItems = computed(() => {
  return [{ label: 'Активных категорий', value: String(menuManager.form.categories.filter((item) => item.isActive).length) }];
});

const itemSummaryItems = computed(() => {
  return [{ label: 'С картинкой', value: String(menuManager.form.items.filter((item) => item.imageUrl.trim()).length) }];
});

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, branchId]) => {
    if ((mode === 'detail' || mode === 'edit') && branchId) {
      if (menuManager.selectedBranchId !== branchId) {
        await menuManager.selectBranch(branchId);
      }
      await nextTick();
      editDirty.markClean();
    }
  },
  { immediate: true },
);

onMounted(() => {
  void menuManager.initialize();
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
  await menuManager.save();

  if (!menuManager.contentErrorMessage) {
    editDirty.markClean();
    await routeState.goToDetail(menuManager.selectedBranchId);
  }
}

function resolveCategoryTitle(categoryKey: string) {
  return menuManager.form.categories.find((category) => category.key === categoryKey)?.title || 'Без категории';
}

function formatPrice(priceTenge: number) {
  return `${priceTenge} тг`;
}
</script>

<style scoped>
.menu-detail-view {
  display: grid;
  gap: 12px;
}

.menu-detail-view__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.menu-detail-view__list {
  display: grid;
  gap: 8px;
  margin: 0;
  padding-left: 18px;
}

.menu-editor__preview {
  width: min(240px, 100%);
  overflow: hidden;
  border-radius: 20px;
  border: 1px solid var(--admin-border-default);
}

.menu-editor__preview img {
  display: block;
  width: 100%;
  aspect-ratio: 4 / 3;
  object-fit: cover;
}
</style>
