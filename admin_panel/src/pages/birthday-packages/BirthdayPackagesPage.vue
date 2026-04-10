<template>
  <AdminCrudWorkspace
    eyebrow="Коммерческое предложение"
    title="Пакеты дней рождения"
    description="Пакеты, цены и вместимость по филиалам."
    :mobile-view="mobileView"
    :mobile-detail-title="detailPanelTitle"
    mobile-detail-eyebrow="Рабочая карточка"
    @back="handleBack"
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--primary"
        @click="handleStartCreate"
      >
        Добавить пакет
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Пакеты</h2>
      </div>

      <div class="admin-crud-filters">
        <AdminSearchField
          v-model="packagesManager.searchQuery"
          placeholder="Найти пакет по названию или цене"
        />

        <div class="birthday-packages-page__filter-grid">
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
        </div>
      </div>

      <p
        v-if="packagesManager.branchesErrorMessage"
        class="admin-inline-message admin-inline-message--error"
      >
        {{ packagesManager.branchesErrorMessage }}
      </p>

      <StatePanel
        v-if="packagesManager.isListLoading"
        title="Загружаем пакеты"
        description="Подождите немного, список обновляется с сервера."
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
        description="Проверьте фильтры или строку поиска."
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
          @click="handleSelectPackage(item.id)"
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
        v-if="packagesManager.isCreating"
        title="Новый пакет"
        description="Создайте коммерческое предложение для мобильного приложения."
      />

      <StatePanel
        v-else-if="packagesManager.isDetailLoading"
        title="Открываем пакет"
        description="Подтягиваем описание, параметры и публикацию."
      />

      <StatePanel
        v-else-if="packagesManager.detailErrorMessage"
        title="Не удалось открыть пакет"
        :description="packagesManager.detailErrorMessage"
        tone="error"
      />

      <form
        v-if="packagesManager.isCreating"
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
            @click="handleBack"
          >
            Отменить
          </button>
        </AdminStickyActions>
      </form>

      <template v-else-if="packagesManager.selectedPackage">
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
        </header>

        <form
          ref="editFormRef"
          class="admin-form-stack"
          novalidate
          @submit.prevent="handleSave"
        >
          <div class="admin-section-heading">
            <h3>Основные данные</h3>
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
          </AdminStickyActions>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите пакет"
        description="Откройте пакет, чтобы изменить описание и цену."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';

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
import AdminFormErrorBanner from '@/shared/ui/AdminFormErrorBanner.vue';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminStickyActions from '@/shared/ui/AdminStickyActions.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const packagesManager = reactive(useAdminBirthdayPackages());
const mobileView = ref<'list' | 'detail'>('list');
const createFormRef = ref<HTMLFormElement | null>(null);
const editFormRef = ref<HTMLFormElement | null>(null);
const createSummaryMessage = ref('');
const editSummaryMessage = ref('');
const createFieldErrors = reactive<AdminFieldErrors>({});
const editFieldErrors = reactive<AdminFieldErrors>({});

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
  return [
    { label: 'Все филиалы', value: '' },
    ...branchSelectionOptions.value,
  ];
});

const branchNameMap = computed(() => {
  return new Map(
    packagesManager.branchOptions.map((branch) => [branch.id, branch.name]),
  );
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

const detailPanelTitle = computed(() => {
  if (packagesManager.isCreating) {
    return 'Новый пакет';
  }

  return packagesManager.selectedPackage?.name || 'Карточка пакета';
});

function branchLabel(branchId: string): string {
  return branchNameMap.value.get(branchId) ?? 'Филиал не найден';
}

onMounted(() => {
  void packagesManager.initialize();
});

function handleStartCreate() {
  clearFormFeedback();
  packagesManager.startCreate();
  mobileView.value = 'detail';
}

async function handleSelectPackage(packageId: string) {
  await packagesManager.selectPackage(packageId);
  mobileView.value = 'detail';
}

function handleBack() {
  if (packagesManager.isCreating) {
    packagesManager.cancelCreate();
  }

  clearFormFeedback();
  mobileView.value = 'list';
}

async function handleCreateSubmit() {
  const errors = compactErrors({
    branchId: validateRequiredText(
      packagesManager.createForm.branchId,
      'Выберите филиал.',
      1,
    ),
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
.birthday-packages-page__filter-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.birthday-packages-page__record-meta,
.birthday-packages-page__switches {
  display: grid;
  gap: 8px;
}

.birthday-packages-page__record-meta {
  justify-items: end;
}

.birthday-packages-page__featured {
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 600;
}

@media (max-width: 720px) {
  .birthday-packages-page__filter-grid {
    grid-template-columns: 1fr;
  }
}
</style>
