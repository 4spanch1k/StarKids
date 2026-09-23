<template>
  <AdminCrudWorkspace
    eyebrow="Контент приложения"
    title="Новости"
    description="Новости для главного экрана и истории уведомлений мобильного приложения."
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
        Добавить новость
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Новости</h2>
      </div>

      <AdminCompactFilters>
        <template #primary>
          <AdminSearchField
            v-model="newsManager.searchQuery"
            placeholder="Найти новость"
          />
        </template>

        <template #secondary>
          <AppSelectField
            v-model="newsManager.activeFilter"
            label="Статус"
            :options="activeFilterOptions"
          />
        </template>
      </AdminCompactFilters>

      <StatePanel
        v-if="newsManager.isListLoading"
        title="Загружаем новости"
        description="Подтягиваем ленту новостей с сервера."
      />

      <StatePanel
        v-else-if="newsManager.listErrorMessage"
        title="Не удалось открыть новости"
        :description="newsManager.listErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="newsManager.loadNews"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <StatePanel
        v-else-if="newsManager.filteredNews.length === 0"
        title="Новости не найдены"
        description="Измените фильтры, очистите поиск или добавьте первую новость."
      />

      <div v-else class="news-table-wrap">
        <table class="news-table">
          <thead>
            <tr>
              <th>Превью</th>
              <th>Заголовок</th>
              <th>Порядок</th>
              <th>Публикация</th>
              <th>Статус</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="item in newsManager.filteredNews"
              :key="item.id"
              class="news-table__row"
              :class="{ 'news-table__row--active': item.id === newsManager.selectedNewsId }"
              @click="void routeState.goToDetail(item.id)"
            >
              <td class="news-table__image-cell">
                <img
                  v-if="item.imageUrl"
                  :src="item.imageUrl"
                  :alt="item.title"
                  class="news-table__image"
                />
                <span v-else class="news-table__image-placeholder">Нет изображения</span>
              </td>
              <td>
                <strong>{{ item.title }}</strong>
                <p>{{ item.description || 'Без описания' }}</p>
              </td>
              <td>{{ item.displayOrder }}</td>
              <td>{{ formatDateTime(item.publishAt) || 'Сразу' }}</td>
              <td>
                <StatusBadge
                  :label="resolveNewsStatus(item).label"
                  :tone="resolveNewsStatus(item).tone"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <template #detail>
      <StatePanel
        v-if="newsManager.isDetailLoading && routeMode !== 'create'"
        title="Открываем новость"
        description="Подтягиваем карточку новости и ее текущий статус."
      />

      <StatePanel
        v-else-if="newsManager.detailErrorMessage && routeMode !== 'create'"
        title="Не удалось открыть новость"
        :description="newsManager.detailErrorMessage"
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
            <h2>Создать новость</h2>
          </div>

          <div class="admin-form-grid--two">
            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.title) }"
              data-field="title"
            >
              <span class="admin-field__label">Заголовок</span>
              <input
                v-model="newsManager.createForm.title"
                name="title"
                class="admin-control"
                :maxlength="NEWS_TITLE_MAX_LENGTH"
                @input="clearCreateFieldError('title')"
              />
              <span class="news-page__field-hint">
                {{ newsManager.createForm.title.length }}/{{ NEWS_TITLE_MAX_LENGTH }}
              </span>
              <p v-if="createFieldErrors.title" class="admin-field__error">
                {{ createFieldErrors.title }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.displayOrder) }"
              data-field="displayOrder"
            >
              <span class="admin-field__label">Порядок</span>
              <input
                v-model.number="newsManager.createForm.displayOrder"
                name="displayOrder"
                type="number"
                min="0"
                max="1000"
                class="admin-control"
                @input="clearCreateFieldError('displayOrder')"
              />
              <p v-if="createFieldErrors.displayOrder" class="admin-field__error">
                {{ createFieldErrors.displayOrder }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.publishAt) }"
              data-field="publishAt"
            >
              <span class="admin-field__label">Дата публикации</span>
              <input
                v-model="newsManager.createForm.publishAt"
                name="publishAt"
                type="datetime-local"
                class="admin-control"
                @input="clearCreateFieldError('publishAt')"
              />
              <p v-if="createFieldErrors.publishAt" class="admin-field__error">
                {{ createFieldErrors.publishAt }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.description) }"
              data-field="description"
            >
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="newsManager.createForm.description"
                name="description"
                class="admin-control admin-control--textarea"
                @input="clearCreateFieldError('description')"
              ></textarea>
              <p v-if="createFieldErrors.description" class="admin-field__error">
                {{ createFieldErrors.description }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.imageUrl) }"
              data-field="imageUrl"
            >
              <span class="admin-field__label">Изображение новости</span>
              <input
                v-model="newsManager.createForm.imageUrl"
                name="imageUrl"
                class="admin-control"
                placeholder="https://..."
                @input="clearCreateFieldError('imageUrl')"
              />
              <p v-if="createFieldErrors.imageUrl" class="admin-field__error">
                {{ createFieldErrors.imageUrl }}
              </p>

              <div class="news-page__upload-row">
                <input
                  class="admin-control"
                  type="file"
                  accept="image/png,image/jpeg,image/webp"
                  :disabled="newsManager.isCreateImageUploading"
                  @change="void handleCreateImageUpload($event)"
                />
                <span class="news-page__upload-hint">
                  JPG, PNG или WebP, до 5 МБ.
                </span>
              </div>
            </label>
          </div>

          <div
            v-if="newsManager.createForm.imageUrl"
            class="news-page__image-preview"
          >
            <img
              :src="newsManager.createForm.imageUrl"
              alt="Предпросмотр новости"
            />
          </div>

          <div class="news-preview-card">
            <div
              class="news-preview-card__media"
              :class="{ 'news-preview-card__media--empty': !newsManager.createForm.imageUrl }"
            >
              <img
                v-if="newsManager.createForm.imageUrl"
                :src="newsManager.createForm.imageUrl"
                alt="Предпросмотр карточки новости"
              />
              <span v-else>Изображение обязательно</span>
            </div>
            <div class="news-preview-card__body">
              <p class="news-preview-card__eyebrow">Предпросмотр перед сохранением</p>
              <strong>{{ newsManager.createForm.title || 'Заголовок новости' }}</strong>
              <p>
                {{
                  newsManager.createForm.description ||
                    'Короткий анонс появится здесь после заполнения описания.'
                }}
              </p>
            </div>
          </div>

          <div class="news-page__switches">
            <AdminSwitchField
              v-model="newsManager.createForm.isActive"
              label="Показывать в приложении"
              hint="Неактивная новость скрывается с главного экрана и из колокола."
            />
          </div>

          <AdminFormErrorBanner
            v-if="createSummaryMessage || newsManager.createErrorMessage"
            :message="createSummaryMessage || newsManager.createErrorMessage"
            :errors="createFieldErrors"
          />
          <p
            v-if="newsManager.createSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ newsManager.createSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="newsManager.isCreateSaving || newsManager.isCreateImageUploading"
            >
              {{ newsManager.isCreateSaving ? 'Сохраняем…' : 'Создать новость' }}
            </button>
            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="void handlePanelClose()"
            >
              Отмена
            </button>
          </AdminStickyActions>
        </form>
      </template>

      <template v-else-if="routeMode === 'edit' && newsManager.selectedNews">
        <form
          ref="editFormRef"
          class="admin-form-stack"
          novalidate
          @submit.prevent="handleSave"
        >
          <div class="admin-section-heading">
            <h2>Редактировать новость</h2>
          </div>

          <div class="admin-form-grid--two">
            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.title) }"
              data-field="title"
            >
              <span class="admin-field__label">Заголовок</span>
              <input
                v-model="newsManager.form.title"
                name="title"
                class="admin-control"
                :maxlength="NEWS_TITLE_MAX_LENGTH"
                @input="clearEditFieldError('title')"
              />
              <span class="news-page__field-hint">
                {{ (newsManager.form.title || '').length }}/{{ NEWS_TITLE_MAX_LENGTH }}
              </span>
              <p v-if="editFieldErrors.title" class="admin-field__error">
                {{ editFieldErrors.title }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.displayOrder) }"
              data-field="displayOrder"
            >
              <span class="admin-field__label">Порядок</span>
              <input
                v-model.number="newsManager.form.displayOrder"
                name="displayOrder"
                type="number"
                min="0"
                max="1000"
                class="admin-control"
                @input="clearEditFieldError('displayOrder')"
              />
              <p v-if="editFieldErrors.displayOrder" class="admin-field__error">
                {{ editFieldErrors.displayOrder }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.publishAt) }"
              data-field="publishAt"
            >
              <span class="admin-field__label">Дата публикации</span>
              <input
                v-model="newsManager.form.publishAt"
                name="publishAt"
                type="datetime-local"
                class="admin-control"
                @input="clearEditFieldError('publishAt')"
              />
              <p v-if="editFieldErrors.publishAt" class="admin-field__error">
                {{ editFieldErrors.publishAt }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.description) }"
              data-field="description"
            >
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="newsManager.form.description"
                name="description"
                class="admin-control admin-control--textarea"
                @input="clearEditFieldError('description')"
              ></textarea>
              <p v-if="editFieldErrors.description" class="admin-field__error">
                {{ editFieldErrors.description }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.imageUrl) }"
              data-field="imageUrl"
            >
              <span class="admin-field__label">Изображение новости</span>
              <input
                v-model="newsManager.form.imageUrl"
                name="imageUrl"
                class="admin-control"
                placeholder="https://..."
                @input="clearEditFieldError('imageUrl')"
              />
              <p v-if="editFieldErrors.imageUrl" class="admin-field__error">
                {{ editFieldErrors.imageUrl }}
              </p>

              <div class="news-page__upload-row">
                <input
                  class="admin-control"
                  type="file"
                  accept="image/png,image/jpeg,image/webp"
                  :disabled="newsManager.isEditImageUploading"
                  @change="void handleEditImageUpload($event)"
                />
                <span class="news-page__upload-hint">
                  JPG, PNG или WebP, до 5 МБ.
                </span>
              </div>
            </label>
          </div>

          <div
            v-if="newsManager.form.imageUrl"
            class="news-page__image-preview"
          >
            <img
              :src="newsManager.form.imageUrl || ''"
              alt="Предпросмотр новости"
            />
          </div>

          <div class="news-preview-card">
            <div
              class="news-preview-card__media"
              :class="{ 'news-preview-card__media--empty': !newsManager.form.imageUrl }"
            >
              <img
                v-if="newsManager.form.imageUrl"
                :src="newsManager.form.imageUrl || ''"
                alt="Предпросмотр карточки новости"
              />
              <span v-else>Изображение обязательно</span>
            </div>
            <div class="news-preview-card__body">
              <p class="news-preview-card__eyebrow">Предпросмотр перед сохранением</p>
              <strong>{{ newsManager.form.title || 'Заголовок новости' }}</strong>
              <p>
                {{
                  newsManager.form.description ||
                    'Короткий анонс появится здесь после заполнения описания.'
                }}
              </p>
            </div>
          </div>

          <div class="news-page__switches">
            <AdminSwitchField
              v-model="newsIsActive"
              label="Показывать в приложении"
              hint="Неактивная новость скрывается с главного экрана и из колокола."
            />
          </div>

          <AdminFormErrorBanner
            v-if="editSummaryMessage || newsManager.saveErrorMessage"
            :message="editSummaryMessage || newsManager.saveErrorMessage"
            :errors="editFieldErrors"
          />
          <p
            v-if="newsManager.saveSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ newsManager.saveSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="newsManager.isSaving || newsManager.isEditImageUploading"
            >
              {{ newsManager.isSaving ? 'Сохраняем…' : 'Сохранить новость' }}
            </button>
            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="void handlePanelClose()"
            >
              Отмена
            </button>
          </AdminStickyActions>
        </form>
      </template>

      <template v-else-if="routeMode === 'detail' && newsManager.selectedNews">
        <div class="news-detail-view">
          <div
            v-if="newsManager.selectedNews.imageUrl"
            class="news-page__image-preview news-page__image-preview--detail"
          >
            <img
              :src="newsManager.selectedNews.imageUrl"
              :alt="newsManager.selectedNews.title"
            />
          </div>

          <div class="admin-section-heading">
            <h2>{{ newsManager.selectedNews.title }}</h2>
          </div>

          <div class="news-detail-view__actions">
            <StatusBadge
              :label="resolveNewsStatus(newsManager.selectedNews).label"
              :tone="resolveNewsStatus(newsManager.selectedNews).tone"
            />
            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="void routeState.goToEdit(newsManager.selectedNews.id)"
            >
              Редактировать
            </button>
            <button
              type="button"
              class="admin-button admin-button--secondary news-detail-view__delete-button"
              @click="void handleDelete()"
            >
              Удалить
            </button>
          </div>

          <AdminSummaryList
            title="Сводка"
            :items="newsSummaryItems"
          />
          <AdminSummaryList
            title="Статус"
            :items="newsMetaItems"
          />
        </div>
      </template>

      <StatePanel
        v-else
        title="Выберите новость"
        description="Откройте запись, чтобы посмотреть детали или отредактировать публикацию."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import { useAdminNews } from '@/features/news/model/useAdminNews';
import type { AdminFieldErrors } from '@/shared/lib/adminApiErrors';
import {
  resolveAdminApiErrorMessage,
  resolveAdminApiFieldErrors,
} from '@/shared/lib/adminApiErrors';
import {
  clearFieldError,
  focusFirstFieldError,
  replaceFieldErrors,
  validateMaxTextLength,
  validateNonNegativeNumber,
  validateRequiredText,
  validateRequiredUrl,
} from '@/shared/lib/adminFormValidation';
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

const newsManager = reactive(useAdminNews());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.news.list,
  detailRouteName: adminCrudRouteNames.news.detail,
  createRouteName: adminCrudRouteNames.news.create,
  editRouteName: adminCrudRouteNames.news.edit,
  idParam: adminCrudRouteNames.news.idParam,
});

const createFormRef = ref<HTMLFormElement | null>(null);
const editFormRef = ref<HTMLFormElement | null>(null);
const createSummaryMessage = ref('');
const editSummaryMessage = ref('');
const createFieldErrors = reactive<AdminFieldErrors>({});
const editFieldErrors = reactive<AdminFieldErrors>({});

const createDirty = useFormSnapshotDirty(() => ({ ...newsManager.createForm }));
const editDirty = useFormSnapshotDirty(() => ({ ...newsManager.form }));
const NEWS_TITLE_MAX_LENGTH = 80;

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
  { label: 'Все статусы', value: 'all' },
  { label: 'Активные', value: 'active' },
  { label: 'Выключенные', value: 'inactive' },
];

const routeMode = computed(() => routeState.mode.value);

const showInlineDetail = computed(() => {
  return routeState.isDesktop.value && routeMode.value === 'detail' && Boolean(newsManager.selectedNews);
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
    return 'Создать новость';
  }

  if (routeMode.value === 'edit') {
    return newsManager.selectedNews?.title || 'Редактировать новость';
  }

  return newsManager.selectedNews?.title || 'Карточка новости';
});

const routePanelEyebrow = computed(() => {
  return routeMode.value === 'detail' ? 'Карточка новости' : 'Редактирование';
});

const routePanelVariant = computed<'detail' | 'form'>(() => {
  return routeMode.value === 'detail' ? 'detail' : 'form';
});

const routePanelCloseLabel = computed(() => {
  return routeMode.value === 'detail' ? 'К списку' : 'Закрыть';
});

const newsIsActive = computed({
  get() {
    return Boolean(newsManager.form.isActive);
  },
  set(value: boolean) {
    newsManager.form.isActive = value;
  },
});

const newsSummaryItems = computed(() => {
  const item = newsManager.selectedNews;
  if (!item) {
    return [];
  }

  return [
    { label: 'Описание', value: item.description || 'Без описания', fullWidth: true },
  ];
});

const newsMetaItems = computed(() => {
  const item = newsManager.selectedNews;
  if (!item) {
    return [];
  }

  return [
    { label: 'Дата создания', value: formatDate(item.createdAt) },
    { label: 'Дата публикации', value: formatDateTime(item.publishAt) || 'Сразу' },
    { label: 'Порядок', value: String(item.displayOrder) },
    { label: 'Показывать в приложении', value: item.isActive ? 'Да' : 'Нет' },
  ];
});

const newsFieldLabels: Record<string, string> = {
  title: 'заголовок',
  imageUrl: 'изображение',
  description: 'описание',
  displayOrder: 'порядок',
  publishAt: 'дата публикации',
};

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, newsId]) => {
    if (mode === 'create') {
      clearFormFeedback();
      newsManager.startCreate();
      await nextTick();
      createDirty.markClean();
      return;
    }

    if ((mode === 'detail' || mode === 'edit') && newsId) {
      if (newsManager.selectedNewsId !== newsId || !newsManager.selectedNews) {
        await newsManager.selectNews(newsId);
      }
      await nextTick();
      editDirty.markClean();
    }
  },
  { immediate: true },
);

onMounted(() => {
  void newsManager.initialize();
});

async function handlePanelClose() {
  if ((routeMode.value === 'create' || routeMode.value === 'edit') && !confirmLeave()) {
    return;
  }

  clearFormFeedback();

  if (routeMode.value === 'detail') {
    await routeState.closeDetail();
    return;
  }

  if (routeMode.value === 'create' && newsManager.isCreating) {
    newsManager.cancelCreate();
  }

  await routeState.closeEditor();
}

async function handleCreateSubmit() {
  const errors = compactErrors({
    title:
      validateRequiredText(newsManager.createForm.title, 'Введите заголовок.', 2) ||
      validateMaxTextLength(
        newsManager.createForm.title,
        NEWS_TITLE_MAX_LENGTH,
        `Заголовок должен быть не длиннее ${NEWS_TITLE_MAX_LENGTH} символов.`,
      ),
    description: validateRequiredText(
      newsManager.createForm.description,
      'Введите описание новости.',
      3,
    ),
    imageUrl: validateRequiredUrl(
      newsManager.createForm.imageUrl,
      'Добавьте изображение новости.',
      'Укажите корректную ссылку на изображение.',
    ),
    displayOrder: validateNonNegativeNumber(
      Number(newsManager.createForm.displayOrder),
      'Порядок должен быть числом от 0 и выше.',
    ),
  });

  replaceFieldErrors(createFieldErrors, errors);
  createSummaryMessage.value = formatValidationSummary(errors);

  if (Object.keys(errors).length > 0) {
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
    return;
  }

  try {
    createSummaryMessage.value = '';
    const createdNews = await newsManager.saveCreate();
    createDirty.markClean();

    if (createdNews?.id) {
      await routeState.goToDetail(createdNews.id);
    }
  } catch (error) {
    replaceFieldErrors(createFieldErrors, resolveAdminApiFieldErrors(error));
    createSummaryMessage.value = Object.keys(createFieldErrors).length
      ? formatValidationSummary(createFieldErrors)
      : resolveAdminApiErrorMessage(error, 'Не удалось создать новость.');
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
  }
}

async function handleSave() {
  const errors = compactErrors({
    title:
      validateRequiredText(newsManager.form.title || '', 'Введите заголовок.', 2) ||
      validateMaxTextLength(
        newsManager.form.title || '',
        NEWS_TITLE_MAX_LENGTH,
        `Заголовок должен быть не длиннее ${NEWS_TITLE_MAX_LENGTH} символов.`,
      ),
    description: validateRequiredText(
      newsManager.form.description || '',
      'Введите описание новости.',
      3,
    ),
    imageUrl: validateRequiredUrl(
      newsManager.form.imageUrl || '',
      'Добавьте изображение новости.',
      'Укажите корректную ссылку на изображение.',
    ),
    displayOrder: validateNonNegativeNumber(
      Number(newsManager.form.displayOrder ?? 0),
      'Порядок должен быть числом от 0 и выше.',
    ),
  });

  replaceFieldErrors(editFieldErrors, errors);
  editSummaryMessage.value = formatValidationSummary(errors);

  if (Object.keys(errors).length > 0) {
    await focusFirstFieldError(editFormRef.value, editFieldErrors);
    return;
  }

  try {
    editSummaryMessage.value = '';
    const savedNews = await newsManager.save();
    editDirty.markClean();

    if (savedNews?.id) {
      await routeState.goToDetail(savedNews.id);
    }
  } catch (error) {
    replaceFieldErrors(editFieldErrors, resolveAdminApiFieldErrors(error));
    editSummaryMessage.value = Object.keys(editFieldErrors).length
      ? formatValidationSummary(editFieldErrors)
      : resolveAdminApiErrorMessage(error, 'Не удалось сохранить новость.');
    await focusFirstFieldError(editFormRef.value, editFieldErrors);
  }
}

async function handleDelete() {
  const item = newsManager.selectedNews;
  if (!item) {
    return;
  }

  const confirmed = window.confirm(`Удалить новость «${item.title}»?`);
  if (!confirmed) {
    return;
  }

  try {
    await newsManager.removeSelectedNews();
    await routeState.goToList();
  } catch (error) {
    editSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось удалить новость.',
    );
  }
}

async function handleCreateImageUpload(event: Event) {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file) {
    return;
  }

  try {
    await newsManager.uploadCreateImage(file);
    clearCreateFieldError('imageUrl');
  } finally {
    target.value = '';
  }
}

async function handleEditImageUpload(event: Event) {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file) {
    return;
  }

  try {
    await newsManager.uploadEditImage(file);
    clearEditFieldError('imageUrl');
  } finally {
    target.value = '';
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

function formatValidationSummary(errors: AdminFieldErrors): string {
  const labels = Object.keys(errors)
    .map((field) => newsFieldLabels[field])
    .filter(Boolean);

  if (!labels.length) {
    return '';
  }

  if (labels.length === 1) {
    return `Проверьте поле: ${labels[0]}.`;
  }

  return `Проверьте поля: ${labels.join(', ')}.`;
}

function resolveNewsStatus(item: { isActive: boolean; publishAt?: string | null }) {
  if (!item.isActive) {
    return { label: 'Выключена', tone: 'warning' as const };
  }

  if (item.publishAt) {
    const publishAt = new Date(item.publishAt);
    if (!Number.isNaN(publishAt.getTime()) && publishAt.getTime() > Date.now()) {
      return { label: 'Запланирована', tone: 'in-progress' as const };
    }
  }

  return { label: 'Активна', tone: 'closed' as const };
}

function formatDate(value: string) {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return 'Не указано';
  }

  return parsed.toLocaleDateString('ru-RU', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

function formatDateTime(value: string | null) {
  if (!value) {
    return '';
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return 'Не указано';
  }

  return parsed.toLocaleString('ru-RU', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}
</script>

<style scoped>
.news-table-wrap {
  overflow-x: auto;
}

.news-table {
  width: 100%;
  border-collapse: collapse;
}

.news-table th,
.news-table td {
  padding: 14px 12px;
  border-bottom: 1px solid var(--color-border);
  text-align: left;
  vertical-align: middle;
}

.news-table th {
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.news-table__row {
  cursor: pointer;
  transition: background-color 120ms ease;
}

.news-table__row:hover,
.news-table__row--active {
  background: var(--color-surface-subtle);
}

.news-table__image-cell {
  width: 128px;
}

.news-table__image,
.news-page__image-preview img {
  width: 112px;
  height: 72px;
  object-fit: cover;
  border-radius: 14px;
  border: 1px solid var(--color-border);
}

.news-table td p,
.news-table td strong {
  margin: 0;
}

.news-table td p {
  margin-top: 4px;
  color: var(--color-muted);
}

.news-table__image-placeholder {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 112px;
  height: 72px;
  border-radius: 14px;
  border: 1px dashed var(--color-border);
  color: var(--color-muted);
  font-size: 12px;
}

.news-page__upload-row,
.news-page__switches,
.news-detail-view {
  display: grid;
  gap: 10px;
}

.news-page__upload-hint {
  color: var(--color-muted);
  font-size: 12px;
}

.news-page__field-hint {
  margin-top: 6px;
  color: var(--color-muted);
  font-size: 12px;
}

.news-page__image-preview {
  display: inline-flex;
  padding: 12px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: var(--color-surface-subtle);
}

.news-preview-card {
  display: grid;
  gap: 14px;
  padding: 16px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: var(--color-surface-subtle);
}

.news-preview-card__media {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 180px;
  border-radius: 16px;
  overflow: hidden;
  background: linear-gradient(135deg, rgba(255, 214, 228, 0.9), rgba(219, 233, 255, 0.9));
}

.news-preview-card__media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.news-preview-card__media--empty {
  border: 1px dashed var(--color-border);
  color: var(--color-muted);
  font-size: 13px;
}

.news-preview-card__body {
  display: grid;
  gap: 8px;
}

.news-preview-card__body strong,
.news-preview-card__body p {
  margin: 0;
}

.news-preview-card__body p:last-child {
  color: var(--color-muted);
}

.news-preview-card__eyebrow {
  color: var(--color-muted);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.news-page__image-preview--detail img {
  width: min(100%, 360px);
  height: auto;
  aspect-ratio: 16 / 9;
}

.news-detail-view__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.news-detail-view__delete-button {
  border-color: rgba(180, 35, 24, 0.18);
  color: var(--color-danger);
  background: var(--color-danger-soft);
}

@media (max-width: 720px) {
  .news-table {
    min-width: 620px;
  }
}
</style>
