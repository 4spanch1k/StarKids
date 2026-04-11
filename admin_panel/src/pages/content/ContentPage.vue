<template>
  <AdminCrudWorkspace
    eyebrow="Контент"
    title="Контент приложения"
    description="Тексты и CTA для клиентских экранов."
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
        Добавить блок
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Контентные блоки</h2>
      </div>

      <AdminCompactFilters>
        <template #primary>
          <AdminSearchField
            v-model="contentBlocksManager.searchQuery"
            placeholder="Найти блок"
          />
        </template>

        <template #secondary>
          <AppSelectField
            v-model="contentBlocksManager.surfaceFilter"
            label="Поверхность"
            :options="surfaceFilterOptions"
          />

          <AppSelectField
            v-model="contentBlocksManager.activeFilter"
            label="Статус"
            :options="toggleFilterOptions"
          />

          <AppSelectField
            v-model="contentBlocksManager.publicationFilter"
            label="Публикация"
            :options="publicationFilterOptions"
          />
        </template>
      </AdminCompactFilters>

      <StatePanel
        v-if="contentBlocksManager.isListLoading"
        title="Загружаем контент"
        description="Подтягиваем список блоков с сервера."
      />

      <StatePanel
        v-else-if="contentBlocksManager.listErrorMessage"
        title="Не удалось открыть контент"
        :description="contentBlocksManager.listErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="contentBlocksManager.loadContentBlocks"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <StatePanel
        v-else-if="contentBlocksManager.filteredBlocks.length === 0"
        title="Контентные блоки не найдены"
        description="Измените фильтры или очистите поиск."
      />

      <div v-else class="admin-list-records">
        <button
          v-for="block in contentBlocksManager.filteredBlocks"
          :key="block.id"
          type="button"
          class="admin-list-record"
          :class="{ 'admin-list-record--active': block.id === contentBlocksManager.selectedBlockId }"
          @click="void routeState.goToDetail(block.id)"
        >
          <span class="admin-list-record__accent" aria-hidden="true"></span>
          <div class="admin-list-record__copy">
            <strong>{{ block.title }}</strong>
            <p>{{ contentSurfaceLabel(block.surface) }}</p>
            <span>{{ block.key }}</span>
          </div>
          <StatusBadge
            :label="resolvePublicationStatus(block).label"
            :tone="resolvePublicationStatus(block).tone"
          />
        </button>
      </div>
    </template>

    <template #detail>
      <StatePanel
        v-if="contentBlocksManager.isDetailLoading && routeMode !== 'create'"
        title="Открываем блок"
        description="Загружаем текст и настройки публикации."
      />

      <StatePanel
        v-else-if="contentBlocksManager.detailErrorMessage && routeMode !== 'create'"
        title="Не удалось открыть блок"
        :description="contentBlocksManager.detailErrorMessage"
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
            <h2>Создать блок</h2>
          </div>

          <div class="admin-form-grid--two">
            <div
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.surface) }"
              data-field="surface"
            >
              <AppSelectField
                v-model="contentBlocksManager.createForm.surface"
                label="Поверхность"
                :options="surfaceSelectOptions"
              />
              <p v-if="createFieldErrors.surface" class="admin-field__error">
                {{ createFieldErrors.surface }}
              </p>
            </div>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.key) }"
              data-field="key"
            >
              <span class="admin-field__label">Ключ блока</span>
              <input
                v-model="contentBlocksManager.createForm.key"
                name="key"
                class="admin-control"
                @input="clearCreateFieldError('key')"
              />
              <p v-if="createFieldErrors.key" class="admin-field__error">
                {{ createFieldErrors.key }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.title) }"
              data-field="title"
            >
              <span class="admin-field__label">Заголовок</span>
              <input
                v-model="contentBlocksManager.createForm.title"
                name="title"
                class="admin-control"
                @input="clearCreateFieldError('title')"
              />
              <p v-if="createFieldErrors.title" class="admin-field__error">
                {{ createFieldErrors.title }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.body) }"
              data-field="body"
            >
              <span class="admin-field__label">Текст</span>
              <textarea
                v-model="contentBlocksManager.createForm.body"
                name="body"
                class="admin-control admin-control--textarea"
                @input="clearCreateFieldError('body')"
              ></textarea>
              <p v-if="createFieldErrors.body" class="admin-field__error">
                {{ createFieldErrors.body }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.ctaLabel) }"
              data-field="ctaLabel"
            >
              <span class="admin-field__label">Текст кнопки</span>
              <input
                v-model="contentBlocksManager.createForm.ctaLabel"
                name="ctaLabel"
                class="admin-control"
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
                v-model.number="contentBlocksManager.createForm.displayOrder"
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
          </div>

          <div class="content-page__switches">
            <AdminSwitchField
              v-model="contentBlocksManager.createForm.isPublished"
              label="Опубликовать в приложении"
              hint="Черновик не будет показан пользователям."
            />
            <AdminSwitchField
              v-model="contentBlocksManager.createForm.isActive"
              label="Блок активен"
              hint="Выключенный блок можно сохранить без удаления."
            />
          </div>

          <AdminFormErrorBanner
            v-if="createSummaryMessage"
            :message="createSummaryMessage"
            :errors="createFieldErrors"
          />
          <p
            v-if="contentBlocksManager.createSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ contentBlocksManager.createSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="contentBlocksManager.isCreateSaving"
            >
              {{ contentBlocksManager.isCreateSaving ? 'Сохраняем…' : 'Создать блок' }}
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

      <template v-else-if="contentBlocksManager.selectedBlock">
        <template v-if="routeMode === 'detail'">
          <div class="content-detail-view">
            <header class="admin-detail-header">
              <div class="admin-detail-header__copy">
                <p class="admin-detail-header__eyebrow">
                  Код: {{ contentBlocksManager.selectedBlock.id }}
                </p>
                <div class="admin-detail-header__title-row">
                  <h2>{{ contentBlocksManager.selectedBlock.title }}</h2>
                  <StatusBadge
                    :label="resolvePublicationStatus(contentBlocksManager.selectedBlock).label"
                    :tone="resolvePublicationStatus(contentBlocksManager.selectedBlock).tone"
                  />
                </div>
                <p class="admin-detail-header__summary">
                  {{ contentSurfaceLabel(contentBlocksManager.selectedBlock.surface) }} ·
                  {{ contentBlocksManager.selectedBlock.key }}
                </p>
              </div>

              <div class="content-detail-view__actions">
                <button
                  type="button"
                  class="admin-button admin-button--primary"
                  @click="void routeState.goToEdit(contentBlocksManager.selectedBlock.id)"
                >
                  Редактировать
                </button>
              </div>
            </header>

            <AdminSummaryList
              title="Текст и структура"
              :items="blockSummaryItems"
            />

            <AdminSummaryList
              title="Статус"
              :items="blockStateItems"
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
            <h2>Редактировать блок</h2>
          </div>

          <div class="admin-form-grid--two">
            <div
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.surface) }"
              data-field="surface"
            >
              <AppSelectField
                v-model="blockSurface"
                label="Поверхность"
                :options="surfaceSelectOptions"
              />
              <p v-if="editFieldErrors.surface" class="admin-field__error">
                {{ editFieldErrors.surface }}
              </p>
            </div>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.key) }"
              data-field="key"
            >
              <span class="admin-field__label">Ключ блока</span>
              <input
                v-model="contentBlocksManager.form.key"
                name="key"
                class="admin-control"
                @input="clearEditFieldError('key')"
              />
              <p v-if="editFieldErrors.key" class="admin-field__error">
                {{ editFieldErrors.key }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.title) }"
              data-field="title"
            >
              <span class="admin-field__label">Заголовок</span>
              <input
                v-model="contentBlocksManager.form.title"
                name="title"
                class="admin-control"
                @input="clearEditFieldError('title')"
              />
              <p v-if="editFieldErrors.title" class="admin-field__error">
                {{ editFieldErrors.title }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.body) }"
              data-field="body"
            >
              <span class="admin-field__label">Текст</span>
              <textarea
                v-model="contentBlocksManager.form.body"
                name="body"
                class="admin-control admin-control--textarea"
                @input="clearEditFieldError('body')"
              ></textarea>
              <p v-if="editFieldErrors.body" class="admin-field__error">
                {{ editFieldErrors.body }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.ctaLabel) }"
              data-field="ctaLabel"
            >
              <span class="admin-field__label">Текст кнопки</span>
              <input
                v-model="contentBlocksManager.form.ctaLabel"
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
                v-model.number="contentBlocksManager.form.displayOrder"
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
          </div>

          <div class="content-page__switches">
            <AdminSwitchField
              v-model="blockIsPublished"
              label="Опубликовать в приложении"
              hint="Публикация включает блок для клиентских экранов."
            />
            <AdminSwitchField
              v-model="blockIsActive"
              label="Блок активен"
              hint="Выключенный блок сохраняется, но не участвует в выдаче."
            />
          </div>

          <AdminFormErrorBanner
            v-if="editSummaryMessage"
            :message="editSummaryMessage"
            :errors="editFieldErrors"
          />
          <p
            v-if="contentBlocksManager.saveSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ contentBlocksManager.saveSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="contentBlocksManager.isSaving"
            >
              {{ contentBlocksManager.isSaving ? 'Сохраняем…' : 'Сохранить блок' }}
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
        title="Выберите блок"
        description="Откройте блок, чтобы посмотреть детали или перейти к редактированию."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import {
  contentSurfaceOptions,
  getContentSurfaceLabel,
} from '@/features/content/model/contentSurface';
import { useAdminContentBlocks } from '@/features/content/model/useAdminContentBlocks';
import type { AdminFieldErrors } from '@/shared/lib/adminApiErrors';
import {
  resolveAdminApiErrorMessage,
  resolveAdminApiFieldErrors,
} from '@/shared/lib/adminApiErrors';
import {
  clearFieldError,
  focusFirstFieldError,
  replaceFieldErrors,
  validateNonNegativeNumber,
  validateOptionalText,
  validateRequiredText,
} from '@/shared/lib/adminFormValidation';
import { resolvePublicationStatus } from '@/shared/lib/adminStatus';
import { useAdminCrudRouteState } from '@/shared/composables/useAdminCrudRouteState';
import { useFormSnapshotDirty } from '@/shared/composables/useFormSnapshotDirty';
import { useUnsavedChangesGuard } from '@/shared/composables/useUnsavedChangesGuard';
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

const contentBlocksManager = reactive(useAdminContentBlocks());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.content.list,
  detailRouteName: adminCrudRouteNames.content.detail,
  createRouteName: adminCrudRouteNames.content.create,
  editRouteName: adminCrudRouteNames.content.edit,
  idParam: adminCrudRouteNames.content.idParam,
});

const createFormRef = ref<HTMLFormElement | null>(null);
const editFormRef = ref<HTMLFormElement | null>(null);
const createSummaryMessage = ref('');
const editSummaryMessage = ref('');
const createFieldErrors = reactive<AdminFieldErrors>({});
const editFieldErrors = reactive<AdminFieldErrors>({});

const createDirty = useFormSnapshotDirty(() => ({ ...contentBlocksManager.createForm }));
const editDirty = useFormSnapshotDirty(() => ({ ...contentBlocksManager.form }));

const { confirmLeave } = useUnsavedChangesGuard(() => {
  if (routeMode.value === 'create') {
    return createDirty.isDirty.value;
  }

  if (routeMode.value === 'edit') {
    return editDirty.isDirty.value;
  }

  return false;
});

const toggleFilterOptions = [
  { label: 'Все состояния', value: 'all' },
  { label: 'Да', value: 'yes' },
  { label: 'Нет', value: 'no' },
];

const publicationFilterOptions = [
  { label: 'Любая публикация', value: 'all' },
  { label: 'Опубликовано', value: 'yes' },
  { label: 'Черновик', value: 'no' },
];

const surfaceSelectOptions = computed(() => {
  const entries = new Map(contentSurfaceOptions.map((option) => [option.value, option.label]));

  for (const surface of contentBlocksManager.surfaceOptions) {
    if (!entries.has(surface)) {
      entries.set(surface, getContentSurfaceLabel(surface));
    }
  }

  return Array.from(entries.entries()).map(([value, label]) => ({ value, label }));
});

const surfaceFilterOptions = computed(() => {
  return [{ label: 'Все поверхности', value: '' }, ...surfaceSelectOptions.value];
});

const routeMode = computed(() => routeState.mode.value);

const showInlineDetail = computed(() => {
  return (
    routeState.isDesktop.value &&
    routeMode.value === 'detail' &&
    Boolean(contentBlocksManager.selectedBlock)
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
    return 'Создать блок';
  }

  if (routeMode.value === 'edit') {
    return contentBlocksManager.selectedBlock?.title || 'Редактировать блок';
  }

  return contentBlocksManager.selectedBlock?.title || 'Карточка блока';
});

const routePanelEyebrow = computed(() => {
  return routeMode.value === 'detail' ? 'Карточка блока' : 'Редактирование';
});

const routePanelVariant = computed<'detail' | 'form'>(() => {
  return routeMode.value === 'detail' ? 'detail' : 'form';
});

const routePanelCloseLabel = computed(() => {
  return routeMode.value === 'detail' ? 'К списку' : 'Закрыть';
});

const blockIsActive = computed({
  get() {
    return Boolean(contentBlocksManager.form.isActive);
  },
  set(value: boolean) {
    contentBlocksManager.form.isActive = value;
  },
});

const blockIsPublished = computed({
  get() {
    return Boolean(contentBlocksManager.form.isPublished);
  },
  set(value: boolean) {
    contentBlocksManager.form.isPublished = value;
  },
});

const blockSurface = computed({
  get() {
    return contentBlocksManager.form.surface ?? 'home';
  },
  set(value: string) {
    contentBlocksManager.form.surface = value;
  },
});

const blockSummaryItems = computed(() => {
  const block = contentBlocksManager.selectedBlock;
  if (!block) {
    return [];
  }

  return [
    { label: 'Поверхность', value: contentSurfaceLabel(block.surface) },
    { label: 'Ключ', value: block.key },
    { label: 'Порядок показа', value: String(block.displayOrder) },
    { label: 'Текст кнопки', value: block.ctaLabel || 'Не задан' },
    { label: 'Текст', value: block.body, fullWidth: true },
  ];
});

const blockStateItems = computed(() => {
  const block = contentBlocksManager.selectedBlock;
  if (!block) {
    return [];
  }

  return [
    { label: 'Активность', value: block.isActive ? 'Активен' : 'Выключен' },
    { label: 'Публикация', value: block.isPublished ? 'Опубликован' : 'Черновик' },
  ];
});

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, blockId]) => {
    if (mode === 'create') {
      clearFormFeedback();
      contentBlocksManager.startCreate();
      await nextTick();
      createDirty.markClean();
      return;
    }

    if ((mode === 'detail' || mode === 'edit') && blockId) {
      if (contentBlocksManager.selectedBlockId !== blockId || !contentBlocksManager.selectedBlock) {
        await contentBlocksManager.selectBlock(blockId);
      }
      await nextTick();
      editDirty.markClean();
    }
  },
  { immediate: true },
);

onMounted(() => {
  void contentBlocksManager.initialize();
});

function contentSurfaceLabel(surface: string): string {
  return getContentSurfaceLabel(surface);
}

async function handlePanelClose() {
  if ((routeMode.value === 'create' || routeMode.value === 'edit') && !confirmLeave()) {
    return;
  }

  clearFormFeedback();

  if (routeMode.value === 'detail') {
    await routeState.closeDetail();
    return;
  }

  if (routeMode.value === 'create' && contentBlocksManager.isCreating) {
    contentBlocksManager.cancelCreate();
  }

  await routeState.closeEditor();
}

async function handleCreateSubmit() {
  const errors = compactErrors({
    surface: validateRequiredText(contentBlocksManager.createForm.surface, 'Выберите поверхность.', 1),
    key: validateRequiredText(contentBlocksManager.createForm.key, 'Введите ключ блока.', 1),
    title: validateRequiredText(contentBlocksManager.createForm.title, 'Введите заголовок блока.', 2),
    body: validateRequiredText(contentBlocksManager.createForm.body, 'Введите текст блока.', 2),
    ctaLabel: validateOptionalText(
      contentBlocksManager.createForm.ctaLabel,
      'Текст кнопки слишком длинный.',
      64,
    ),
    displayOrder: validateNonNegativeNumber(
      contentBlocksManager.createForm.displayOrder,
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
    await contentBlocksManager.saveCreate();
    createDirty.markClean();

    if (contentBlocksManager.selectedBlockId) {
      await routeState.goToDetail(contentBlocksManager.selectedBlockId);
    }
  } catch (error) {
    replaceFieldErrors(createFieldErrors, resolveAdminApiFieldErrors(error));
    createSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось создать контентный блок.',
    );
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
  }
}

async function handleSave() {
  const errors = compactErrors({
    surface: validateRequiredText(contentBlocksManager.form.surface || '', 'Выберите поверхность.', 1),
    key: validateRequiredText(contentBlocksManager.form.key || '', 'Введите ключ блока.', 1),
    title: validateRequiredText(contentBlocksManager.form.title || '', 'Введите заголовок блока.', 2),
    body: validateRequiredText(contentBlocksManager.form.body || '', 'Введите текст блока.', 2),
    ctaLabel: validateOptionalText(
      contentBlocksManager.form.ctaLabel || '',
      'Текст кнопки слишком длинный.',
      64,
    ),
    displayOrder: validateNonNegativeNumber(
      contentBlocksManager.form.displayOrder ?? 0,
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
    await contentBlocksManager.save();
    editDirty.markClean();
    await routeState.goToDetail(contentBlocksManager.selectedBlockId);
  } catch (error) {
    replaceFieldErrors(editFieldErrors, resolveAdminApiFieldErrors(error));
    editSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось сохранить контентный блок.',
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

function clearFormFeedback() {
  replaceFieldErrors(createFieldErrors, {});
  replaceFieldErrors(editFieldErrors, {});
  createSummaryMessage.value = '';
  editSummaryMessage.value = '';
}

function compactErrors(errors: AdminFieldErrors): AdminFieldErrors {
  return Object.fromEntries(
    Object.entries(errors).filter((entry): entry is [string, string] => Boolean(entry[1])),
  );
}
</script>

<style scoped>
.content-page__switches,
.content-detail-view {
  display: grid;
  gap: 8px;
}

.content-detail-view__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
</style>
