<template>
  <AdminCrudWorkspace
    eyebrow="Медиаданные"
    title="Галерея"
    description="Hero-изображение и gallery URL по филиалам."
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
        @click="galleryManager.initialize"
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
        v-if="galleryManager.isBranchesLoading"
        title="Загружаем филиалы"
        description="Подготавливаем список филиалов для медиаданных."
      />

      <StatePanel
        v-else-if="galleryManager.branchesErrorMessage"
        title="Не удалось загрузить филиалы"
        :description="galleryManager.branchesErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="galleryManager.initialize"
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
          :class="{ 'admin-list-record--active': branch.id === galleryManager.selectedBranchId }"
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
        v-if="galleryManager.isGalleryLoading"
        title="Открываем медиаданные"
        description="Подтягиваем текущие ссылки выбранного филиала."
      />

      <StatePanel
        v-else-if="galleryManager.galleryErrorMessage && routeMode === 'detail'"
        title="Не удалось открыть галерею"
        :description="galleryManager.galleryErrorMessage"
        tone="error"
      />

      <template v-else-if="selectedBranch">
        <template v-if="routeMode === 'detail'">
          <div class="gallery-detail-view">
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
                  Метаданные и URL без загрузки файлов.
                </p>
              </div>

              <div class="gallery-detail-view__actions">
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
              title="Hero и галерея"
              :items="gallerySummaryItems"
            />

            <AdminSummaryList
              v-if="galleryManager.form.galleryImageUrls.length"
              title="Изображения галереи"
            >
              <ul class="gallery-detail-view__list">
                <li
                  v-for="url in galleryManager.form.galleryImageUrls"
                  :key="url"
                >
                  {{ url }}
                </li>
              </ul>
            </AdminSummaryList>
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
            <h2>Редактировать галерею</h2>
          </div>

          <label
            class="admin-field"
            :class="{ 'admin-field--error': Boolean(fieldErrors.heroImageUrl) }"
            data-field="heroImageUrl"
          >
            <span class="admin-field__label">Hero-изображение</span>
            <input
              v-model="galleryManager.form.heroImageUrl"
              class="admin-control"
              placeholder="https://..."
              @input="clearField('heroImageUrl')"
            />
            <p v-if="fieldErrors.heroImageUrl" class="admin-field__error">
              {{ fieldErrors.heroImageUrl }}
            </p>
          </label>

          <label
            class="admin-field"
            :class="{ 'admin-field--error': Boolean(fieldErrors.galleryImageUrls) }"
            data-field="galleryImageUrls"
          >
            <span class="admin-field__label">Изображения галереи</span>
            <textarea
              v-model="galleryUrlsText"
              class="admin-control admin-control--textarea"
              placeholder="Каждая строка — отдельный URL"
              @input="clearField('galleryImageUrls')"
            ></textarea>
            <p v-if="fieldErrors.galleryImageUrls" class="admin-field__error">
              {{ fieldErrors.galleryImageUrls }}
            </p>
          </label>

          <AdminFormErrorBanner
            v-if="summaryMessage"
            :message="summaryMessage"
            :errors="fieldErrors"
          />
          <p
            v-if="galleryManager.successMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ galleryManager.successMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="galleryManager.isSaving"
            >
              {{ galleryManager.isSaving ? 'Сохраняем…' : 'Сохранить галерею' }}
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
        description="Откройте филиал, чтобы посмотреть или изменить hero и галерею."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import { useBranchGalleryManager } from '@/features/branches/model/useBranchGalleryManager';
import type { AdminFieldErrors } from '@/shared/lib/adminApiErrors';
import { resolveAdminApiErrorMessage } from '@/shared/lib/adminApiErrors';
import {
  clearFieldError,
  focusFirstFieldError,
  replaceFieldErrors,
  validateOptionalUrl,
} from '@/shared/lib/adminFormValidation';
import { resolveActiveStatus } from '@/shared/lib/adminStatus';
import { parseTextList, stringifyTextList } from '@/shared/lib/textList';
import { useAdminCrudRouteState } from '@/shared/composables/useAdminCrudRouteState';
import { useFormSnapshotDirty } from '@/shared/composables/useFormSnapshotDirty';
import { useUnsavedChangesGuard } from '@/shared/composables/useUnsavedChangesGuard';
import AdminCompactFilters from '@/shared/ui/AdminCompactFilters.vue';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminFormErrorBanner from '@/shared/ui/AdminFormErrorBanner.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminStickyActions from '@/shared/ui/AdminStickyActions.vue';
import AdminSummaryList from '@/shared/ui/AdminSummaryList.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const galleryManager = reactive(useBranchGalleryManager());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.gallery.list,
  detailRouteName: adminCrudRouteNames.gallery.detail,
  editRouteName: adminCrudRouteNames.gallery.edit,
  idParam: adminCrudRouteNames.gallery.idParam,
});

const editFormRef = ref<HTMLFormElement | null>(null);
const searchQuery = ref('');
const summaryMessage = ref('');
const fieldErrors = reactive<AdminFieldErrors>({});

const editDirty = useFormSnapshotDirty(() => ({
  heroImageUrl: galleryManager.form.heroImageUrl,
  galleryImageUrls: [...galleryManager.form.galleryImageUrls],
}));

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
    return selectedBranch.value?.name || 'Редактировать галерею';
  }

  return selectedBranch.value?.name || 'Карточка филиала';
});

const routePanelEyebrow = computed(() => {
  return routeMode.value === 'detail' ? 'Карточка галереи' : 'Редактирование';
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
    return galleryManager.branchOptions;
  }

  return galleryManager.branchOptions.filter((branch) => {
    return `${branch.name} ${branch.city} ${branch.shortLabel}`
      .toLowerCase()
      .includes(query);
  });
});

const selectedBranch = computed(() => {
  return galleryManager.branchOptions.find((branch) => {
    return branch.id === galleryManager.selectedBranchId;
  }) ?? null;
});

const gallerySummaryItems = computed(() => {
  return [
    {
      label: 'Hero-изображение',
      value: galleryManager.form.heroImageUrl || 'Не задано',
      fullWidth: true,
    },
    {
      label: 'Количество изображений',
      value: String(galleryManager.form.galleryImageUrls.length),
    },
  ];
});

const galleryUrlsText = computed({
  get() {
    return stringifyTextList(galleryManager.form.galleryImageUrls);
  },
  set(value: string) {
    galleryManager.form.galleryImageUrls = parseTextList(value);
  },
});

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, branchId]) => {
    if ((mode === 'detail' || mode === 'edit') && branchId) {
      if (galleryManager.selectedBranchId !== branchId) {
        await galleryManager.selectBranch(branchId);
      }
      await nextTick();
      editDirty.markClean();
    }
  },
  { immediate: true },
);

onMounted(() => {
  void galleryManager.initialize();
});

async function handlePanelClose() {
  if (routeMode.value === 'edit' && !confirmLeave()) {
    return;
  }

  clearFeedback();

  if (routeMode.value === 'detail') {
    await routeState.closeDetail();
    return;
  }

  await routeState.closeEditor();
}

async function handleSave() {
  const urls = parseTextList(galleryUrlsText.value);
  const invalidGalleryUrl = urls.some((url) => validateOptionalUrl(url, 'bad') !== '');

  const errors = compactErrors({
    heroImageUrl: validateOptionalUrl(
      galleryManager.form.heroImageUrl,
      'Введите корректную ссылку на hero-изображение.',
    ),
    galleryImageUrls: invalidGalleryUrl
      ? 'Проверьте ссылки в списке изображений галереи.'
      : '',
  });

  replaceFieldErrors(fieldErrors, errors);
  summaryMessage.value = Object.keys(errors).length ? 'Проверьте заполненные ссылки.' : '';

  if (Object.keys(errors).length > 0) {
    await focusFirstFieldError(editFormRef.value, fieldErrors);
    return;
  }

  try {
    summaryMessage.value = '';
    await galleryManager.save();
    editDirty.markClean();
    await routeState.goToDetail(galleryManager.selectedBranchId);
  } catch (error) {
    summaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось сохранить медиаданные филиала.',
    );
  }
}

function clearField(field: string) {
  clearFieldError(fieldErrors, field);
  summaryMessage.value = '';
}

function clearFeedback() {
  replaceFieldErrors(fieldErrors, {});
  summaryMessage.value = '';
}

function compactErrors(errors: AdminFieldErrors): AdminFieldErrors {
  return Object.fromEntries(
    Object.entries(errors).filter((entry): entry is [string, string] => Boolean(entry[1])),
  );
}
</script>

<style scoped>
.gallery-detail-view {
  display: grid;
  gap: 12px;
}

.gallery-detail-view__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.gallery-detail-view__list {
  display: grid;
  gap: 8px;
  margin: 0;
  padding-left: 18px;
}
</style>
