<template>
  <AdminCrudWorkspace
    eyebrow="Акции"
    title="Акции"
    description="Офферы, публикация и филиалы показа."
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
        class="admin-button admin-button--primary"
        @click="void routeState.goToCreate()"
      >
        Добавить акцию
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Акции</h2>
      </div>

      <AdminCompactFilters>
        <template #primary>
          <AdminSearchField
            v-model="promotionsManager.searchQuery"
            placeholder="Найти акцию"
          />
        </template>

        <template #secondary>
          <AppSelectField
            v-model="promotionsManager.branchFilter"
            label="Филиал"
            :options="branchFilterOptions"
            :disabled="promotionsManager.isBranchesLoading"
          />

          <AppSelectField
            v-model="promotionsManager.activeFilter"
            label="Статус"
            :options="activeFilterOptions"
          />

          <AppSelectField
            v-model="promotionsManager.publicationFilter"
            label="Публикация"
            :options="publicationFilterOptions"
          />
        </template>
      </AdminCompactFilters>

      <p
        v-if="promotionsManager.branchesErrorMessage"
        class="admin-inline-message admin-inline-message--error"
      >
        {{ promotionsManager.branchesErrorMessage }}
      </p>

      <StatePanel
        v-if="promotionsManager.isListLoading"
        title="Загружаем акции"
        description="Обновляем список офферов с сервера."
      />

      <StatePanel
        v-else-if="promotionsManager.listErrorMessage"
        title="Не удалось открыть акции"
        :description="promotionsManager.listErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="promotionsManager.loadPromotions"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <StatePanel
        v-else-if="promotionsManager.filteredPromotions.length === 0"
        title="Акции не найдены"
        description="Измените фильтры или очистите строку поиска."
      />

      <div v-else class="admin-list-records">
        <button
          v-for="promotion in promotionsManager.filteredPromotions"
          :key="promotion.id"
          type="button"
          class="admin-list-record"
          :class="{
            'admin-list-record--active': promotion.id === promotionsManager.selectedPromotionId,
          }"
          @click="void routeState.goToDetail(promotion.id)"
        >
          <span class="admin-list-record__accent" aria-hidden="true"></span>

          <div class="admin-list-record__copy">
            <strong>{{ promotion.title }}</strong>
            <p>{{ promotion.badgeLabel || 'Без бейджа' }}</p>
            <span>{{ promotionScopeLabel(promotion.branchIds) }}</span>
          </div>

          <StatusBadge
            :label="resolvePublicationStatus(promotion).label"
            :tone="resolvePublicationStatus(promotion).tone"
          />
        </button>
      </div>
    </template>

    <template #detail>
      <StatePanel
        v-if="promotionsManager.isDetailLoading && routeMode !== 'create'"
        title="Открываем акцию"
        description="Загружаем оффер и статус публикации."
      />

      <StatePanel
        v-else-if="promotionsManager.detailErrorMessage && routeMode !== 'create'"
        title="Не удалось открыть акцию"
        :description="promotionsManager.detailErrorMessage"
        tone="error"
      />

      <template v-else-if="routeMode === 'create'">
        <form
          ref="createFormRef"
          class="admin-form-stack"
          novalidate
          @submit.prevent="handleCreateSubmit"
        >
          <div class="admin-section-heading">
            <h2>Создать акцию</h2>
          </div>

          <div class="admin-form-grid--two">
            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.title) }"
              data-field="title"
            >
              <span class="admin-field__label">Название акции</span>
              <input
                v-model="promotionsManager.createForm.title"
                name="title"
                class="admin-control"
                @input="clearCreateFieldError('title')"
              />
              <p v-if="createFieldErrors.title" class="admin-field__error">
                {{ createFieldErrors.title }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.badgeLabel) }"
              data-field="badgeLabel"
            >
              <span class="admin-field__label">Бейдж</span>
              <input
                v-model="promotionsManager.createForm.badgeLabel"
                name="badgeLabel"
                class="admin-control"
                placeholder="Например, Новинка"
                @input="clearCreateFieldError('badgeLabel')"
              />
              <p v-if="createFieldErrors.badgeLabel" class="admin-field__error">
                {{ createFieldErrors.badgeLabel }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.ctaLabel) }"
              data-field="ctaLabel"
            >
              <span class="admin-field__label">Текст кнопки</span>
              <input
                v-model="promotionsManager.createForm.ctaLabel"
                name="ctaLabel"
                class="admin-control"
                placeholder="Оставить заявку"
                @input="clearCreateFieldError('ctaLabel')"
              />
              <p v-if="createFieldErrors.ctaLabel" class="admin-field__error">
                {{ createFieldErrors.ctaLabel }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.displayOrder) }"
              data-field="displayOrder"
            >
              <span class="admin-field__label">Порядок показа</span>
              <input
                v-model.number="promotionsManager.createForm.displayOrder"
                name="displayOrder"
                min="0"
                type="number"
                class="admin-control"
                @input="clearCreateFieldError('displayOrder')"
              />
              <p v-if="createFieldErrors.displayOrder" class="admin-field__error">
                {{ createFieldErrors.displayOrder }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.imageUrl) }"
              data-field="imageUrl"
            >
              <span class="admin-field__label">Ссылка на изображение</span>
              <input
                v-model="promotionsManager.createForm.imageUrl"
                name="imageUrl"
                class="admin-control"
                placeholder="https://..."
                @input="clearCreateFieldError('imageUrl')"
              />
              <p v-if="createFieldErrors.imageUrl" class="admin-field__error">
                {{ createFieldErrors.imageUrl }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.description) }"
              data-field="description"
            >
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="promotionsManager.createForm.description"
                name="description"
                class="admin-control admin-control--textarea"
                @input="clearCreateFieldError('description')"
              ></textarea>
              <p v-if="createFieldErrors.description" class="admin-field__error">
                {{ createFieldErrors.description }}
              </p>
            </label>
          </div>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Филиалы показа</h3>
              <p>Пустой список означает общую акцию для всех филиалов.</p>
            </div>

            <div class="admin-checkbox-grid">
              <label
                v-for="branch in promotionsManager.branchOptions"
                :key="branch.id"
                class="admin-checkbox-card"
              >
                <input
                  v-model="promotionsManager.createForm.branchIds"
                  type="checkbox"
                  :value="branch.id"
                />
                <span>
                  <strong>{{ branch.name }}</strong>
                  <span>{{ branch.city }} · {{ branch.shortLabel }}</span>
                </span>
              </label>
            </div>
          </section>

          <div class="promotions-page__switches">
            <AdminSwitchField
              v-model="promotionsManager.createForm.isPublished"
              label="Опубликовать в приложении"
              hint="Выключите, если оффер еще готовится к запуску."
            />
            <AdminSwitchField
              v-model="promotionsManager.createForm.isActive"
              label="Акция активна"
              hint="Выключенная акция не будет показываться даже при публикации."
            />
          </div>

          <AdminFormErrorBanner
            v-if="createSummaryMessage"
            :message="createSummaryMessage"
            :errors="createFieldErrors"
          />
          <p
            v-if="promotionsManager.createSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ promotionsManager.createSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="promotionsManager.isCreateSaving"
            >
              {{ promotionsManager.isCreateSaving ? 'Сохраняем…' : 'Создать акцию' }}
            </button>
            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="void handlePanelClose()"
            >
              Отменить
            </button>
          </AdminStickyActions>
        </form>
      </template>

      <template v-else-if="promotionsManager.selectedPromotion">
        <template v-if="routeMode === 'detail'">
          <div class="promotions-detail-view">
            <header class="admin-detail-header">
              <div class="admin-detail-header__copy">
                <p class="admin-detail-header__eyebrow">
                  Код: {{ promotionsManager.selectedPromotion.id }}
                </p>
                <div class="admin-detail-header__title-row">
                  <h2>{{ promotionsManager.selectedPromotion.title }}</h2>
                  <StatusBadge
                    :label="resolvePublicationStatus(promotionsManager.selectedPromotion).label"
                    :tone="resolvePublicationStatus(promotionsManager.selectedPromotion).tone"
                  />
                </div>
                <p class="admin-detail-header__summary">
                  {{ promotionScopeLabel(promotionsManager.selectedPromotion.branchIds) }}
                </p>
              </div>

              <div class="promotions-detail-view__actions">
                <button
                  type="button"
                  class="admin-button admin-button--primary"
                  @click="void routeState.goToEdit(promotionsManager.selectedPromotion.id)"
                >
                  Редактировать
                </button>
              </div>
            </header>

            <AdminSummaryList
              title="Оффер"
              :items="promotionSummaryItems"
            />

            <AdminSummaryList
              title="Публикация"
              :items="promotionPublicationItems"
            />
          </div>
        </template>

        <form
          v-else
          ref="editFormRef"
          class="admin-form-stack"
          novalidate
          @submit.prevent="handleSave"
        >
          <div class="admin-section-heading">
            <h2>Редактировать акцию</h2>
          </div>

          <div class="admin-form-grid--two">
            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.title) }"
              data-field="title"
            >
              <span class="admin-field__label">Название акции</span>
              <input
                v-model="promotionsManager.form.title"
                name="title"
                class="admin-control"
                @input="clearEditFieldError('title')"
              />
              <p v-if="editFieldErrors.title" class="admin-field__error">
                {{ editFieldErrors.title }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.badgeLabel) }"
              data-field="badgeLabel"
            >
              <span class="admin-field__label">Бейдж</span>
              <input
                v-model="promotionsManager.form.badgeLabel"
                name="badgeLabel"
                class="admin-control"
                placeholder="Например, Новинка"
                @input="clearEditFieldError('badgeLabel')"
              />
              <p v-if="editFieldErrors.badgeLabel" class="admin-field__error">
                {{ editFieldErrors.badgeLabel }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.ctaLabel) }"
              data-field="ctaLabel"
            >
              <span class="admin-field__label">Текст кнопки</span>
              <input
                v-model="promotionsManager.form.ctaLabel"
                name="ctaLabel"
                class="admin-control"
                @input="clearEditFieldError('ctaLabel')"
              />
              <p v-if="editFieldErrors.ctaLabel" class="admin-field__error">
                {{ editFieldErrors.ctaLabel }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.displayOrder) }"
              data-field="displayOrder"
            >
              <span class="admin-field__label">Порядок показа</span>
              <input
                v-model.number="promotionsManager.form.displayOrder"
                name="displayOrder"
                min="0"
                type="number"
                class="admin-control"
                @input="clearEditFieldError('displayOrder')"
              />
              <p v-if="editFieldErrors.displayOrder" class="admin-field__error">
                {{ editFieldErrors.displayOrder }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.imageUrl) }"
              data-field="imageUrl"
            >
              <span class="admin-field__label">Ссылка на изображение</span>
              <input
                v-model="promotionsManager.form.imageUrl"
                name="imageUrl"
                class="admin-control"
                placeholder="https://..."
                @input="clearEditFieldError('imageUrl')"
              />
              <p v-if="editFieldErrors.imageUrl" class="admin-field__error">
                {{ editFieldErrors.imageUrl }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.description) }"
              data-field="description"
            >
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="promotionsManager.form.description"
                name="description"
                class="admin-control admin-control--textarea"
                @input="clearEditFieldError('description')"
              ></textarea>
              <p v-if="editFieldErrors.description" class="admin-field__error">
                {{ editFieldErrors.description }}
              </p>
            </label>
          </div>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Филиалы показа</h3>
              <p>Оставьте список пустым, если акция должна считаться общей.</p>
            </div>

            <div class="admin-checkbox-grid">
              <label
                v-for="branch in promotionsManager.branchOptions"
                :key="branch.id"
                class="admin-checkbox-card"
              >
                <input
                  v-model="promotionBranchIds"
                  type="checkbox"
                  :value="branch.id"
                />
                <span>
                  <strong>{{ branch.name }}</strong>
                  <span>{{ branch.city }} · {{ branch.shortLabel }}</span>
                </span>
              </label>
            </div>
          </section>

          <div class="promotions-page__switches">
            <AdminSwitchField
              v-model="promotionIsPublished"
              label="Опубликовать в приложении"
              hint="Включите, когда оффер готов к показу пользователям."
            />
            <AdminSwitchField
              v-model="promotionIsActive"
              label="Акция активна"
              hint="Выключенная акция снимается с показа без удаления."
            />
          </div>

          <AdminFormErrorBanner
            v-if="editSummaryMessage"
            :message="editSummaryMessage"
            :errors="editFieldErrors"
          />
          <p
            v-if="promotionsManager.saveSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ promotionsManager.saveSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="promotionsManager.isSaving"
            >
              {{ promotionsManager.isSaving ? 'Сохраняем…' : 'Сохранить акцию' }}
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
        title="Выберите акцию"
        description="Откройте оффер, чтобы посмотреть детали или перейти к редактированию."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import { useAdminPromotions } from '@/features/promotions/model/useAdminPromotions';
import type { AdminFieldErrors } from '@/shared/lib/adminApiErrors';
import {
  resolveAdminApiErrorMessage,
  resolveAdminApiFieldErrors,
} from '@/shared/lib/adminApiErrors';
import { resolvePublicationStatus } from '@/shared/lib/adminStatus';
import { useAdminCrudRouteState } from '@/shared/composables/useAdminCrudRouteState';
import { useFormSnapshotDirty } from '@/shared/composables/useFormSnapshotDirty';
import { useUnsavedChangesGuard } from '@/shared/composables/useUnsavedChangesGuard';
import {
  clearFieldError,
  focusFirstFieldError,
  replaceFieldErrors,
  validateNonNegativeNumber,
  validateOptionalUrl,
  validateRequiredText,
} from '@/shared/lib/adminFormValidation';
import AdminCompactFilters from '@/shared/ui/AdminCompactFilters.vue';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminFormErrorBanner from '@/shared/ui/AdminFormErrorBanner.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminStickyActions from '@/shared/ui/AdminStickyActions.vue';
import AdminSummaryList from '@/shared/ui/AdminSummaryList.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const promotionsManager = reactive(useAdminPromotions());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.promotions.list,
  detailRouteName: adminCrudRouteNames.promotions.detail,
  createRouteName: adminCrudRouteNames.promotions.create,
  editRouteName: adminCrudRouteNames.promotions.edit,
  idParam: adminCrudRouteNames.promotions.idParam,
});

const createFormRef = ref<HTMLFormElement | null>(null);
const editFormRef = ref<HTMLFormElement | null>(null);
const createSummaryMessage = ref('');
const editSummaryMessage = ref('');
const createFieldErrors = reactive<AdminFieldErrors>({});
const editFieldErrors = reactive<AdminFieldErrors>({});

const createDirty = useFormSnapshotDirty(() => ({
  ...promotionsManager.createForm,
  branchIds: [...promotionsManager.createForm.branchIds],
}));

const editDirty = useFormSnapshotDirty(() => ({
  ...promotionsManager.form,
  branchIds: [...(promotionsManager.form.branchIds ?? [])],
}));

const { confirmLeave } = useUnsavedChangesGuard(() => {
  if (routeMode.value === 'create') {
    return createDirty.isDirty.value;
  }

  if (routeMode.value === 'edit') {
    return editDirty.isDirty.value;
  }

  return false;
});

const activeFilterOptions = [
  { label: 'Все состояния', value: 'all' },
  { label: 'Активные', value: 'active' },
  { label: 'Выключенные', value: 'inactive' },
];

const publicationFilterOptions = [
  { label: 'Любая публикация', value: 'all' },
  { label: 'Опубликованные', value: 'published' },
  { label: 'Черновики', value: 'draft' },
];

const branchFilterOptions = computed(() => {
  return [
    { label: 'Все филиалы', value: '' },
    ...promotionsManager.branchOptions.map((branch) => ({
      value: branch.id,
      label: `${branch.name} · ${branch.city}`,
    })),
  ];
});

const branchNameMap = computed(() => {
  return new Map(
    promotionsManager.branchOptions.map((branch) => [branch.id, branch.name]),
  );
});

const routeMode = computed(() => routeState.mode.value);

const showInlineDetail = computed(() => {
  return (
    routeState.isDesktop.value &&
    routeMode.value === 'detail' &&
    Boolean(promotionsManager.selectedPromotion)
  );
});

const isRoutePanelOpen = computed(() => {
  return (
    routeState.showDetailRoutePanel.value ||
    routeMode.value === 'create' ||
    routeMode.value === 'edit'
  );
});

const routePanelTitle = computed(() => {
  if (routeMode.value === 'create') {
    return 'Создать акцию';
  }

  if (routeMode.value === 'edit') {
    return promotionsManager.selectedPromotion?.title || 'Редактировать акцию';
  }

  return promotionsManager.selectedPromotion?.title || 'Карточка акции';
});

const routePanelEyebrow = computed(() => {
  return routeMode.value === 'detail' ? 'Карточка акции' : 'Редактирование';
});

const routePanelVariant = computed<'detail' | 'form'>(() => {
  return routeMode.value === 'detail' ? 'detail' : 'form';
});

const routePanelCloseLabel = computed(() => {
  return routeMode.value === 'detail' ? 'К списку' : 'Закрыть';
});

const promotionBranchIds = computed({
  get() {
    return promotionsManager.form.branchIds ?? [];
  },
  set(value: string[]) {
    promotionsManager.form.branchIds = value;
  },
});

const promotionIsActive = computed({
  get() {
    return Boolean(promotionsManager.form.isActive);
  },
  set(value: boolean) {
    promotionsManager.form.isActive = value;
  },
});

const promotionIsPublished = computed({
  get() {
    return Boolean(promotionsManager.form.isPublished);
  },
  set(value: boolean) {
    promotionsManager.form.isPublished = value;
  },
});

const promotionSummaryItems = computed(() => {
  const promotion = promotionsManager.selectedPromotion;
  if (!promotion) {
    return [];
  }

  return [
    { label: 'Бейдж', value: promotion.badgeLabel || 'Без бейджа' },
    { label: 'Кнопка', value: promotion.ctaLabel },
    { label: 'Порядок показа', value: String(promotion.displayOrder) },
    {
      label: 'Филиалы показа',
      value: promotionScopeLabel(promotion.branchIds),
      fullWidth: true,
    },
    { label: 'Описание', value: promotion.description, fullWidth: true },
  ];
});

const promotionPublicationItems = computed(() => {
  const promotion = promotionsManager.selectedPromotion;
  if (!promotion) {
    return [];
  }

  return [
    { label: 'Активность', value: promotion.isActive ? 'Активна' : 'Выключена' },
    { label: 'Публикация', value: promotion.isPublished ? 'Опубликована' : 'Черновик' },
    { label: 'Изображение', value: promotion.imageUrl || 'Не задано', fullWidth: true },
  ];
});

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, promotionId]) => {
    if (mode === 'create') {
      clearPromotionFeedback();
      promotionsManager.startCreate();
      await nextTick();
      createDirty.markClean();
      return;
    }

    if ((mode === 'detail' || mode === 'edit') && promotionId) {
      if (
        promotionsManager.selectedPromotionId !== promotionId ||
        !promotionsManager.selectedPromotion
      ) {
        await promotionsManager.selectPromotion(promotionId);
      }
      await nextTick();
      editDirty.markClean();
    }
  },
  { immediate: true },
);

onMounted(() => {
  void promotionsManager.initialize();
});

function promotionScopeLabel(branchIds: string[]): string {
  if (branchIds.length === 0) {
    return 'Все филиалы';
  }

  return branchIds
    .map((branchId) => branchNameMap.value.get(branchId) ?? 'Неизвестный филиал')
    .join(', ');
}

async function handlePanelClose() {
  if ((routeMode.value === 'create' || routeMode.value === 'edit') && !confirmLeave()) {
    return;
  }

  clearPromotionFeedback();

  if (routeMode.value === 'detail') {
    await routeState.closeDetail();
    return;
  }

  if (routeMode.value === 'create' && promotionsManager.isCreating) {
    promotionsManager.cancelCreate();
  }

  await routeState.closeEditor();
}

async function handleCreateSubmit() {
  const errors = compactErrors({
    title: validateRequiredText(promotionsManager.createForm.title, 'Введите название акции.', 2),
    badgeLabel: validateRequiredText(
      promotionsManager.createForm.badgeLabel,
      'Введите бейдж акции.',
      1,
    ),
    ctaLabel: validateRequiredText(
      promotionsManager.createForm.ctaLabel,
      'Введите текст кнопки.',
      1,
    ),
    description: validateRequiredText(
      promotionsManager.createForm.description,
      'Добавьте описание акции.',
      10,
    ),
    imageUrl: validateOptionalUrl(
      promotionsManager.createForm.imageUrl,
      'Введите корректную ссылку на изображение.',
    ),
    displayOrder: validateNonNegativeNumber(
      promotionsManager.createForm.displayOrder,
      'Введите порядок не меньше 0.',
    ),
  });

  replaceFieldErrors(createFieldErrors, errors);
  createSummaryMessage.value = Object.keys(errors).length ? 'Проверьте обязательные поля.' : '';

  if (Object.keys(errors).length > 0) {
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
    return;
  }

  try {
    createSummaryMessage.value = '';
    await promotionsManager.saveCreate();
    createDirty.markClean();

    if (promotionsManager.selectedPromotionId) {
      await routeState.goToDetail(promotionsManager.selectedPromotionId);
    }
  } catch (error) {
    replaceFieldErrors(createFieldErrors, resolveAdminApiFieldErrors(error));
    createSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось создать акцию.',
    );
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
  }
}

async function handleSave() {
  const errors = compactErrors({
    title: validateRequiredText(promotionsManager.form.title || '', 'Введите название акции.', 2),
    badgeLabel: validateRequiredText(
      promotionsManager.form.badgeLabel || '',
      'Введите бейдж акции.',
      1,
    ),
    ctaLabel: validateRequiredText(
      promotionsManager.form.ctaLabel || '',
      'Введите текст кнопки.',
      1,
    ),
    description: validateRequiredText(
      promotionsManager.form.description || '',
      'Добавьте описание акции.',
      10,
    ),
    imageUrl: validateOptionalUrl(
      promotionsManager.form.imageUrl || '',
      'Введите корректную ссылку на изображение.',
    ),
    displayOrder: validateNonNegativeNumber(
      promotionsManager.form.displayOrder ?? 0,
      'Введите порядок не меньше 0.',
    ),
  });

  replaceFieldErrors(editFieldErrors, errors);
  editSummaryMessage.value = Object.keys(errors).length ? 'Проверьте обязательные поля.' : '';

  if (Object.keys(errors).length > 0) {
    await focusFirstFieldError(editFormRef.value, editFieldErrors);
    return;
  }

  try {
    editSummaryMessage.value = '';
    await promotionsManager.save();
    editDirty.markClean();
    await routeState.goToDetail(promotionsManager.selectedPromotionId);
  } catch (error) {
    replaceFieldErrors(editFieldErrors, resolveAdminApiFieldErrors(error));
    editSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось сохранить акцию.',
    );
    await focusFirstFieldError(editFormRef.value, editFieldErrors);
  }
}

function clearCreateFieldError(field: string) {
  clearFieldError(createFieldErrors, field);
  createSummaryMessage.value = '';
}

function clearEditFieldError(field: string) {
  clearFieldError(editFieldErrors, field);
  editSummaryMessage.value = '';
}

function clearPromotionFeedback() {
  replaceFieldErrors(createFieldErrors, {});
  replaceFieldErrors(editFieldErrors, {});
  createSummaryMessage.value = '';
  editSummaryMessage.value = '';
}

function compactErrors(errors: AdminFieldErrors): AdminFieldErrors {
  return Object.entries(errors).reduce<AdminFieldErrors>((accumulator, [field, message]) => {
    if (message) {
      accumulator[field] = message;
    }
    return accumulator;
  }, {});
}
</script>

<style scoped>
.promotions-page__switches,
.promotions-detail-view {
  display: grid;
  gap: 12px;
}

.promotions-detail-view__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
</style>
