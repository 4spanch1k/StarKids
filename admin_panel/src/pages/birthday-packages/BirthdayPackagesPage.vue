<template>
  <AdminCrudWorkspace
    eyebrow="Коммерческое предложение"
    title="Пакеты дней рождения"
    description="Пакеты, цены и вместимость по филиалам."
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
        Добавить пакет
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Пакеты</h2>
      </div>

      <AdminCompactFilters>
        <template #primary>
          <AdminSearchField
            v-model="packagesManager.searchQuery"
            placeholder="Найти пакет"
          />
        </template>

        <template #secondary>
          <AppSelectField
            v-model="packagesManager.branchFilter"
            label="Филиал"
            :options="branchFilterOptions"
            :disabled="packagesManager.isBranchesLoading"
          />

          <AppSelectField
            v-model="packagesManager.statusFilter"
            label="Статус"
            :options="statusOptions"
          />
        </template>
      </AdminCompactFilters>

      <p
        v-if="packagesManager.branchesErrorMessage"
        class="admin-inline-message admin-inline-message--error"
      >
        {{ packagesManager.branchesErrorMessage }}
      </p>

      <StatePanel
        v-if="packagesManager.isListLoading"
        title="Загружаем пакеты"
        description="Обновляем список коммерческих предложений."
      />

      <StatePanel
        v-else-if="packagesManager.listErrorMessage"
        title="Не удалось открыть пакеты"
        :description="packagesManager.listErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="packagesManager.loadPackages"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <StatePanel
        v-else-if="packagesManager.filteredPackages.length === 0"
        title="Пакеты не найдены"
        description="Измените фильтры или очистите строку поиска."
      />

      <div v-else class="admin-list-records">
        <button
          v-for="item in packagesManager.filteredPackages"
          :key="item.id"
          type="button"
          class="admin-list-record"
          :class="{
            'admin-list-record--active': item.id === packagesManager.selectedPackageId,
          }"
          @click="void routeState.goToDetail(item.id)"
        >
          <span class="admin-list-record__accent" aria-hidden="true"></span>
          <div class="admin-list-record__copy">
            <strong>{{ item.name }}</strong>
            <p>{{ branchLabel(item.branchId) }} · {{ item.priceLabel }}</p>
            <span>{{ item.guestCapacityLabel }}</span>
          </div>

          <div class="birthday-packages-page__record-meta">
            <StatusBadge
              :label="resolveActiveStatus(item.isActive).label"
              :tone="resolveActiveStatus(item.isActive).tone"
            />
            <span
              v-if="item.isFeatured"
              class="birthday-packages-page__featured"
            >
              Флагман
            </span>
          </div>
        </button>
      </div>
    </template>

    <template #detail>
      <StatePanel
        v-if="packagesManager.isDetailLoading && routeMode !== 'create'"
        title="Открываем пакет"
        description="Загружаем описание, цену и параметры показа."
      />

      <StatePanel
        v-else-if="packagesManager.detailErrorMessage && routeMode !== 'create'"
        title="Не удалось открыть пакет"
        :description="packagesManager.detailErrorMessage"
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
            <h2>Создать пакет</h2>
          </div>

          <div class="admin-form-grid--two">
            <div
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.branchId) }"
              data-field="branchId"
            >
              <AppSelectField
                v-model="packagesManager.createForm.branchId"
                label="Филиал"
                :options="branchSelectionOptions"
                :disabled="packagesManager.isBranchesLoading"
              />
              <p v-if="createFieldErrors.branchId" class="admin-field__error">
                {{ createFieldErrors.branchId }}
              </p>
            </div>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.slug) }"
              data-field="slug"
            >
              <span class="admin-field__label">Служебный код</span>
              <input
                v-model="packagesManager.createForm.slug"
                name="slug"
                class="admin-control"
                @input="clearCreateFieldError('slug')"
              />
              <p v-if="createFieldErrors.slug" class="admin-field__error">
                {{ createFieldErrors.slug }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.name) }"
              data-field="name"
            >
              <span class="admin-field__label">Название пакета</span>
              <input
                v-model="packagesManager.createForm.name"
                name="name"
                class="admin-control"
                @input="clearCreateFieldError('name')"
              />
              <p v-if="createFieldErrors.name" class="admin-field__error">
                {{ createFieldErrors.name }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.priceFrom) }"
              data-field="priceFrom"
            >
              <span class="admin-field__label">Цена от</span>
              <input
                v-model.number="packagesManager.createForm.priceFrom"
                name="priceFrom"
                min="0"
                type="number"
                class="admin-control"
                @input="clearCreateFieldError('priceFrom')"
              />
              <p v-if="createFieldErrors.priceFrom" class="admin-field__error">
                {{ createFieldErrors.priceFrom }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.priceLabel) }"
              data-field="priceLabel"
            >
              <span class="admin-field__label">Подпись цены</span>
              <input
                v-model="packagesManager.createForm.priceLabel"
                name="priceLabel"
                class="admin-control"
                @input="clearCreateFieldError('priceLabel')"
              />
              <p v-if="createFieldErrors.priceLabel" class="admin-field__error">
                {{ createFieldErrors.priceLabel }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.guestCapacityLabel) }"
              data-field="guestCapacityLabel"
            >
              <span class="admin-field__label">Вместимость</span>
              <input
                v-model="packagesManager.createForm.guestCapacityLabel"
                name="guestCapacityLabel"
                class="admin-control"
                @input="clearCreateFieldError('guestCapacityLabel')"
              />
              <p v-if="createFieldErrors.guestCapacityLabel" class="admin-field__error">
                {{ createFieldErrors.guestCapacityLabel }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.displayOrder) }"
              data-field="displayOrder"
            >
              <span class="admin-field__label">Порядок показа</span>
              <input
                v-model.number="packagesManager.createForm.displayOrder"
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
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.description) }"
              data-field="description"
            >
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="packagesManager.createForm.description"
                name="description"
                class="admin-control admin-control--textarea"
                @input="clearCreateFieldError('description')"
              ></textarea>
              <p v-if="createFieldErrors.description" class="admin-field__error">
                {{ createFieldErrors.description }}
              </p>
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Короткие преимущества</span>
              <textarea
                v-model="createHighlightsText"
                class="admin-control admin-control--textarea"
                placeholder="Каждая строка — отдельный тезис"
              ></textarea>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.imageUrl) }"
              data-field="imageUrl"
            >
              <span class="admin-field__label">Ссылка на изображение</span>
              <input
                v-model="packagesManager.createForm.imageUrl"
                name="imageUrl"
                class="admin-control"
                placeholder="https://..."
                @input="clearCreateFieldError('imageUrl')"
              />
              <p v-if="createFieldErrors.imageUrl" class="admin-field__error">
                {{ createFieldErrors.imageUrl }}
              </p>
            </label>
          </div>

          <div class="birthday-packages-page__switches">
            <AdminSwitchField
              v-model="packagesManager.createForm.isFeatured"
              label="Показывать как флагманский пакет"
              hint="Используется для акцентного показа в мобильном приложении."
            />
            <AdminSwitchField
              v-model="packagesManager.createForm.isActive"
              label="Пакет активен"
              hint="Неактивный пакет скрывается из мобильного приложения."
            />
          </div>

          <AdminFormErrorBanner
            v-if="createSummaryMessage"
            :message="createSummaryMessage"
            :errors="createFieldErrors"
          />
          <p
            v-if="packagesManager.createSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ packagesManager.createSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="packagesManager.isCreateSaving"
            >
              {{ packagesManager.isCreateSaving ? 'Сохраняем…' : 'Создать пакет' }}
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

      <template v-else-if="packagesManager.selectedPackage">
        <template v-if="routeMode === 'detail'">
          <div class="birthday-packages-detail-view">
            <header class="admin-detail-header">
              <div class="admin-detail-header__copy">
                <p class="admin-detail-header__eyebrow">
                  Код: {{ packagesManager.selectedPackage.id }}
                </p>
                <div class="admin-detail-header__title-row">
                  <h2>{{ packagesManager.selectedPackage.name }}</h2>
                  <StatusBadge
                    :label="resolveActiveStatus(packagesManager.selectedPackage.isActive).label"
                    :tone="resolveActiveStatus(packagesManager.selectedPackage.isActive).tone"
                  />
                </div>
                <p class="admin-detail-header__summary">
                  {{ branchLabel(packagesManager.selectedPackage.branchId) }} ·
                  {{ packagesManager.selectedPackage.priceLabel }}
                </p>
              </div>

              <div class="birthday-packages-detail-view__actions">
                <button
                  type="button"
                  class="admin-button admin-button--primary"
                  @click="void routeState.goToEdit(packagesManager.selectedPackage.id)"
                >
                  Редактировать
                </button>
              </div>
            </header>

            <AdminSummaryList
              title="Основные данные"
              :items="packageSummaryItems"
            />

            <AdminSummaryList
              title="Показы и статус"
              :items="packagePublicationItems"
            />

            <AdminSummaryList
              v-if="packageHighlightsItems.length"
              title="Преимущества"
            >
              <ul class="birthday-packages-detail-view__list">
                <li
                  v-for="highlight in packageHighlightsItems"
                  :key="highlight"
                >
                  {{ highlight }}
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
            <h2>Редактировать пакет</h2>
          </div>

          <div class="admin-form-grid--two">
            <div
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.branchId) }"
              data-field="branchId"
            >
              <AppSelectField
                v-model="packageBranchId"
                label="Филиал"
                :options="branchSelectionOptions"
                :disabled="packagesManager.isBranchesLoading"
              />
              <p v-if="editFieldErrors.branchId" class="admin-field__error">
                {{ editFieldErrors.branchId }}
              </p>
            </div>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.slug) }"
              data-field="slug"
            >
              <span class="admin-field__label">Служебный код</span>
              <input
                v-model="packagesManager.form.slug"
                name="slug"
                class="admin-control"
                @input="clearEditFieldError('slug')"
              />
              <p v-if="editFieldErrors.slug" class="admin-field__error">
                {{ editFieldErrors.slug }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.name) }"
              data-field="name"
            >
              <span class="admin-field__label">Название пакета</span>
              <input
                v-model="packagesManager.form.name"
                name="name"
                class="admin-control"
                @input="clearEditFieldError('name')"
              />
              <p v-if="editFieldErrors.name" class="admin-field__error">
                {{ editFieldErrors.name }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.priceFrom) }"
              data-field="priceFrom"
            >
              <span class="admin-field__label">Цена от</span>
              <input
                v-model.number="packagesManager.form.priceFrom"
                name="priceFrom"
                min="0"
                type="number"
                class="admin-control"
                @input="clearEditFieldError('priceFrom')"
              />
              <p v-if="editFieldErrors.priceFrom" class="admin-field__error">
                {{ editFieldErrors.priceFrom }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.priceLabel) }"
              data-field="priceLabel"
            >
              <span class="admin-field__label">Подпись цены</span>
              <input
                v-model="packagesManager.form.priceLabel"
                name="priceLabel"
                class="admin-control"
                @input="clearEditFieldError('priceLabel')"
              />
              <p v-if="editFieldErrors.priceLabel" class="admin-field__error">
                {{ editFieldErrors.priceLabel }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.guestCapacityLabel) }"
              data-field="guestCapacityLabel"
            >
              <span class="admin-field__label">Вместимость</span>
              <input
                v-model="packagesManager.form.guestCapacityLabel"
                name="guestCapacityLabel"
                class="admin-control"
                @input="clearEditFieldError('guestCapacityLabel')"
              />
              <p v-if="editFieldErrors.guestCapacityLabel" class="admin-field__error">
                {{ editFieldErrors.guestCapacityLabel }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.displayOrder) }"
              data-field="displayOrder"
            >
              <span class="admin-field__label">Порядок показа</span>
              <input
                v-model.number="packagesManager.form.displayOrder"
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
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.description) }"
              data-field="description"
            >
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="packagesManager.form.description"
                name="description"
                class="admin-control admin-control--textarea"
                @input="clearEditFieldError('description')"
              ></textarea>
              <p v-if="editFieldErrors.description" class="admin-field__error">
                {{ editFieldErrors.description }}
              </p>
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Короткие преимущества</span>
              <textarea
                v-model="packageHighlightsText"
                class="admin-control admin-control--textarea"
                placeholder="Каждая строка — отдельный тезис"
              ></textarea>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.imageUrl) }"
              data-field="imageUrl"
            >
              <span class="admin-field__label">Ссылка на изображение</span>
              <input
                v-model="packagesManager.form.imageUrl"
                name="imageUrl"
                class="admin-control"
                placeholder="https://..."
                @input="clearEditFieldError('imageUrl')"
              />
              <p v-if="editFieldErrors.imageUrl" class="admin-field__error">
                {{ editFieldErrors.imageUrl }}
              </p>
            </label>
          </div>

          <div class="birthday-packages-page__switches">
            <AdminSwitchField
              v-model="packageIsFeatured"
              label="Показывать как флагманский пакет"
              hint="Помогает акцентно выделить пакет в мобильном приложении."
            />
            <AdminSwitchField
              v-model="packageIsActive"
              label="Пакет активен"
              hint="Неактивный пакет скрывается из клиентских экранов."
            />
          </div>

          <AdminFormErrorBanner
            v-if="editSummaryMessage"
            :message="editSummaryMessage"
            :errors="editFieldErrors"
          />
          <p
            v-if="packagesManager.saveSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ packagesManager.saveSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="packagesManager.isSaving"
            >
              {{ packagesManager.isSaving ? 'Сохраняем…' : 'Сохранить пакет' }}
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
        title="Выберите пакет"
        description="Откройте пакет, чтобы посмотреть детали или изменить его параметры."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import { useAdminBirthdayPackages } from '@/features/birthday-packages/model/useAdminBirthdayPackages';
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
  validateOptionalUrl,
  validateRequiredText,
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
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const packagesManager = reactive(useAdminBirthdayPackages());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.birthdayPackages.list,
  detailRouteName: adminCrudRouteNames.birthdayPackages.detail,
  createRouteName: adminCrudRouteNames.birthdayPackages.create,
  editRouteName: adminCrudRouteNames.birthdayPackages.edit,
  idParam: adminCrudRouteNames.birthdayPackages.idParam,
});

const createFormRef = ref<HTMLFormElement | null>(null);
const editFormRef = ref<HTMLFormElement | null>(null);
const createSummaryMessage = ref('');
const editSummaryMessage = ref('');
const createFieldErrors = reactive<AdminFieldErrors>({});
const editFieldErrors = reactive<AdminFieldErrors>({});

const createDirty = useFormSnapshotDirty(() => ({
  ...packagesManager.createForm,
  highlights: [...packagesManager.createForm.highlights],
}));

const editDirty = useFormSnapshotDirty(() => ({
  ...packagesManager.form,
  highlights: [...(packagesManager.form.highlights ?? [])],
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

const statusOptions = [
  { label: 'Все статусы', value: 'all' },
  { label: 'Активные', value: 'active' },
  { label: 'Неактивные', value: 'inactive' },
];

const branchSelectionOptions = computed(() => {
  return packagesManager.branchOptions.map((branch) => ({
    value: branch.id,
    label: `${branch.name} · ${branch.city}`,
  }));
});

const branchFilterOptions = computed(() => {
  return [{ label: 'Все филиалы', value: '' }, ...branchSelectionOptions.value];
});

const branchNameMap = computed(() => {
  return new Map(
    packagesManager.branchOptions.map((branch) => [branch.id, branch.name]),
  );
});

const routeMode = computed(() => routeState.mode.value);

const showInlineDetail = computed(() => {
  return (
    routeState.isDesktop.value &&
    routeMode.value === 'detail' &&
    Boolean(packagesManager.selectedPackage)
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
    return 'Создать пакет';
  }

  if (routeMode.value === 'edit') {
    return packagesManager.selectedPackage?.name || 'Редактировать пакет';
  }

  return packagesManager.selectedPackage?.name || 'Карточка пакета';
});

const routePanelEyebrow = computed(() => {
  return routeMode.value === 'detail' ? 'Карточка пакета' : 'Редактирование';
});

const routePanelVariant = computed<'detail' | 'form'>(() => {
  return routeMode.value === 'detail' ? 'detail' : 'form';
});

const routePanelCloseLabel = computed(() => {
  return routeMode.value === 'detail' ? 'К списку' : 'Закрыть';
});

const createHighlightsText = computed({
  get() {
    return stringifyTextList(packagesManager.createForm.highlights);
  },
  set(value: string) {
    packagesManager.createForm.highlights = parseTextList(value);
  },
});

const packageHighlightsText = computed({
  get() {
    return stringifyTextList(packagesManager.form.highlights ?? []);
  },
  set(value: string) {
    packagesManager.form.highlights = parseTextList(value);
  },
});

const packageBranchId = computed({
  get() {
    return packagesManager.form.branchId ?? '';
  },
  set(value: string) {
    packagesManager.form.branchId = value;
  },
});

const packageIsActive = computed({
  get() {
    return Boolean(packagesManager.form.isActive);
  },
  set(value: boolean) {
    packagesManager.form.isActive = value;
  },
});

const packageIsFeatured = computed({
  get() {
    return Boolean(packagesManager.form.isFeatured);
  },
  set(value: boolean) {
    packagesManager.form.isFeatured = value;
  },
});

const packageSummaryItems = computed(() => {
  const selectedPackage = packagesManager.selectedPackage;
  if (!selectedPackage) {
    return [];
  }

  return [
    { label: 'Филиал', value: branchLabel(selectedPackage.branchId) },
    { label: 'Служебный код', value: selectedPackage.slug },
    { label: 'Цена от', value: String(selectedPackage.priceFrom) },
    { label: 'Подпись цены', value: selectedPackage.priceLabel },
    { label: 'Вместимость', value: selectedPackage.guestCapacityLabel },
    { label: 'Порядок показа', value: String(selectedPackage.displayOrder) },
    { label: 'Описание', value: selectedPackage.description, fullWidth: true },
  ];
});

const packagePublicationItems = computed(() => {
  const selectedPackage = packagesManager.selectedPackage;
  if (!selectedPackage) {
    return [];
  }

  return [
    { label: 'Активность', value: selectedPackage.isActive ? 'Активен' : 'Неактивен' },
    { label: 'Флагман', value: selectedPackage.isFeatured ? 'Да' : 'Нет' },
    { label: 'Изображение', value: selectedPackage.imageUrl || 'Не задано', fullWidth: true },
  ];
});

const packageHighlightsItems = computed(() => {
  return packagesManager.selectedPackage?.highlights ?? [];
});

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, packageId]) => {
    if (mode === 'create') {
      clearFormFeedback();
      packagesManager.startCreate();
      await nextTick();
      createDirty.markClean();
      return;
    }

    if ((mode === 'detail' || mode === 'edit') && packageId) {
      if (packagesManager.selectedPackageId !== packageId || !packagesManager.selectedPackage) {
        await packagesManager.selectPackage(packageId);
      }
      await nextTick();
      editDirty.markClean();
    }
  },
  { immediate: true },
);

onMounted(() => {
  void packagesManager.initialize();
});

function branchLabel(branchId: string): string {
  return branchNameMap.value.get(branchId) ?? 'Филиал не найден';
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

  if (routeMode.value === 'create' && packagesManager.isCreating) {
    packagesManager.cancelCreate();
  }

  await routeState.closeEditor();
}

async function handleCreateSubmit() {
  const errors = compactErrors({
    branchId: validateRequiredText(packagesManager.createForm.branchId, 'Выберите филиал.', 1),
    slug: validateRequiredText(packagesManager.createForm.slug, 'Введите служебный код.', 2),
    name: validateRequiredText(packagesManager.createForm.name, 'Введите название пакета.', 2),
    priceFrom: validateNonNegativeNumber(
      packagesManager.createForm.priceFrom,
      'Введите цену не меньше 0.',
    ),
    priceLabel: validateRequiredText(
      packagesManager.createForm.priceLabel,
      'Введите подпись цены.',
      1,
    ),
    guestCapacityLabel: validateRequiredText(
      packagesManager.createForm.guestCapacityLabel,
      'Введите вместимость.',
      1,
    ),
    description: validateRequiredText(
      packagesManager.createForm.description,
      'Добавьте описание пакета.',
      10,
    ),
    imageUrl: validateOptionalUrl(
      packagesManager.createForm.imageUrl || '',
      'Введите корректную ссылку на изображение.',
    ),
    displayOrder: validateNonNegativeNumber(
      packagesManager.createForm.displayOrder,
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
    await packagesManager.saveCreate();
    createDirty.markClean();

    if (packagesManager.selectedPackageId) {
      await routeState.goToDetail(packagesManager.selectedPackageId);
    }
  } catch (error) {
    replaceFieldErrors(createFieldErrors, resolveAdminApiFieldErrors(error));
    createSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось создать пакет.',
    );
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
  }
}

async function handleSave() {
  const errors = compactErrors({
    branchId: validateRequiredText(packagesManager.form.branchId || '', 'Выберите филиал.', 1),
    slug: validateRequiredText(packagesManager.form.slug || '', 'Введите служебный код.', 2),
    name: validateRequiredText(packagesManager.form.name || '', 'Введите название пакета.', 2),
    priceFrom: validateNonNegativeNumber(
      packagesManager.form.priceFrom ?? 0,
      'Введите цену не меньше 0.',
    ),
    priceLabel: validateRequiredText(
      packagesManager.form.priceLabel || '',
      'Введите подпись цены.',
      1,
    ),
    guestCapacityLabel: validateRequiredText(
      packagesManager.form.guestCapacityLabel || '',
      'Введите вместимость.',
      1,
    ),
    description: validateRequiredText(
      packagesManager.form.description || '',
      'Добавьте описание пакета.',
      10,
    ),
    imageUrl: validateOptionalUrl(
      packagesManager.form.imageUrl || '',
      'Введите корректную ссылку на изображение.',
    ),
    displayOrder: validateNonNegativeNumber(
      packagesManager.form.displayOrder ?? 0,
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
    await packagesManager.save();
    editDirty.markClean();
    await routeState.goToDetail(packagesManager.selectedPackageId);
  } catch (error) {
    replaceFieldErrors(editFieldErrors, resolveAdminApiFieldErrors(error));
    editSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось сохранить пакет.',
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
.birthday-packages-page__record-meta,
.birthday-packages-page__switches,
.birthday-packages-detail-view {
  display: grid;
  gap: 8px;
}

.birthday-packages-page__record-meta {
  justify-items: end;
}

.birthday-packages-detail-view__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.birthday-packages-detail-view__list {
  display: grid;
  gap: 8px;
  margin: 0;
  padding-left: 18px;
}

.birthday-packages-page__featured {
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 600;
}
</style>
