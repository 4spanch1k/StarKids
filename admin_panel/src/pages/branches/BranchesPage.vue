<template>
  <AdminCrudWorkspace
    eyebrow="Контент филиалов"
    title="Филиалы"
    description="Филиалы, контакты и базовые параметры."
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
        Добавить филиал
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Филиалы</h2>
      </div>

      <div class="branches-list__filters">
        <AdminSearchField
          v-model="branchesManager.searchQuery"
          placeholder="Найти филиал"
        />

        <AppSelectField
          v-model="branchesManager.statusFilter"
          label="Статус"
          :options="statusOptions"
        />
      </div>

      <StatePanel
        v-if="branchesManager.isListLoading"
        title="Загружаем филиалы"
        description="Подождите немного, обновляем список доступных точек."
      />

      <StatePanel
        v-else-if="branchesManager.listErrorMessage"
        title="Не удалось открыть список филиалов"
        :description="branchesManager.listErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="branchesManager.loadBranches"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <StatePanel
        v-else-if="branchesManager.filteredBranches.length === 0"
        title="Филиалы не найдены"
        description="Проверьте строку поиска или очистите фильтр по статусу."
      />

      <div v-else class="branches-list__items">
        <button
          v-for="branch in branchesManager.filteredBranches"
          :key="branch.id"
          type="button"
          class="branches-list__item"
          :class="{
            'branches-list__item--active': branch.id === branchesManager.selectedBranchId,
          }"
          @click="handleSelectBranch(branch.id)"
        >
          <span class="branches-list__item-accent" aria-hidden="true"></span>
          <div class="branches-list__item-copy">
            <strong>{{ branch.name }}</strong>
            <p>{{ branch.city }} · {{ branch.shortLabel }}</p>
            <span>{{ branch.workingHours }}</span>
          </div>
          <StatusBadge
            :label="branch.isActive ? 'Активен' : 'Неактивен'"
            :tone="branch.isActive ? 'closed' : 'neutral'"
          />
        </button>
      </div>
    </template>

    <template #detail>
      <StatePanel
        v-if="branchesManager.isCreating"
        title="Новый филиал"
        description="Заполните обязательные поля. После создания сможете дополнить тарифы и галерею в соседних разделах."
      />

      <StatePanel
        v-else-if="branchesManager.isDetailLoading"
        title="Открываем филиал"
        description="Загружаем карточку и контакты выбранной точки."
      />

      <StatePanel
        v-else-if="branchesManager.detailErrorMessage"
        title="Не удалось открыть филиал"
        :description="branchesManager.detailErrorMessage"
        tone="error"
      />

      <template v-if="branchesManager.isCreating">
        <form
          ref="createFormRef"
          class="admin-form-stack"
          novalidate
          @submit.prevent="handleCreateSubmit"
        >
          <div class="admin-section-heading">
            <h2>Создать филиал</h2>
          </div>

          <div class="branches-form-grid">
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.slug) }"
              data-field="slug"
            >
              <span class="admin-field__label">Служебный код</span>
              <input
                v-model="branchesManager.createForm.slug"
                name="slug"
                class="admin-control"
                @input="clearCreateFieldError('slug')"
              />
              <p v-if="createFieldErrors.slug" class="admin-field__error">
                {{ createFieldErrors.slug }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.shortLabel) }"
              data-field="shortLabel"
            >
              <span class="admin-field__label">Короткая подпись</span>
              <input
                v-model="branchesManager.createForm.shortLabel"
                name="shortLabel"
                class="admin-control"
                @input="clearCreateFieldError('shortLabel')"
              />
              <p v-if="createFieldErrors.shortLabel" class="admin-field__error">
                {{ createFieldErrors.shortLabel }}
              </p>
            </label>
            <label
              class="admin-field branches-form-grid__full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.name) }"
              data-field="name"
            >
              <span class="admin-field__label">Название филиала</span>
              <input
                v-model="branchesManager.createForm.name"
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
              :class="{ 'admin-field--error': Boolean(createFieldErrors.city) }"
              data-field="city"
            >
              <span class="admin-field__label">Город</span>
              <input
                v-model="branchesManager.createForm.city"
                name="city"
                class="admin-control"
                @input="clearCreateFieldError('city')"
              />
              <p v-if="createFieldErrors.city" class="admin-field__error">
                {{ createFieldErrors.city }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.workingHours) }"
              data-field="workingHours"
            >
              <span class="admin-field__label">Режим работы</span>
              <input
                v-model="branchesManager.createForm.workingHours"
                name="workingHours"
                class="admin-control"
                @input="clearCreateFieldError('workingHours')"
              />
              <p v-if="createFieldErrors.workingHours" class="admin-field__error">
                {{ createFieldErrors.workingHours }}
              </p>
            </label>
            <label
              class="admin-field branches-form-grid__full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.address) }"
              data-field="address"
            >
              <span class="admin-field__label">Адрес</span>
              <input
                v-model="branchesManager.createForm.address"
                name="address"
                class="admin-control"
                @input="clearCreateFieldError('address')"
              />
              <p v-if="createFieldErrors.address" class="admin-field__error">
                {{ createFieldErrors.address }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.phone) }"
              data-field="phone"
            >
              <span class="admin-field__label">Телефон</span>
              <input
                v-model="branchesManager.createForm.phone"
                name="phone"
                class="admin-control"
                @input="clearCreateFieldError('phone')"
              />
              <p v-if="createFieldErrors.phone" class="admin-field__error">
                {{ createFieldErrors.phone }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.whatsappPhone) }"
              data-field="whatsappPhone"
            >
              <span class="admin-field__label">WhatsApp</span>
              <input
                v-model="branchesManager.createForm.whatsappPhone"
                name="whatsappPhone"
                class="admin-control"
                @input="clearCreateFieldError('whatsappPhone')"
              />
              <p v-if="createFieldErrors.whatsappPhone" class="admin-field__error">
                {{ createFieldErrors.whatsappPhone }}
              </p>
            </label>
            <label
              class="admin-field branches-form-grid__full"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.description) }"
              data-field="description"
            >
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="branchesManager.createForm.description"
                name="description"
                class="admin-control admin-control--textarea"
                @input="clearCreateFieldError('description')"
              ></textarea>
              <p v-if="createFieldErrors.description" class="admin-field__error">
                {{ createFieldErrors.description }}
              </p>
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Удобства</span>
              <textarea
                v-model="createFacilitiesText"
                class="admin-control admin-control--textarea"
                placeholder="Каждая строка — отдельное удобство"
              ></textarea>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(createFieldErrors.displayOrder) }"
              data-field="displayOrder"
            >
              <span class="admin-field__label">Порядок</span>
              <input
                v-model.number="branchesManager.createForm.displayOrder"
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

          <AdminSwitchField
            v-model="branchesManager.createForm.isActive"
            label="Филиал активен"
            hint="Неактивный филиал не будет виден в мобильном приложении."
          />

          <AdminFormErrorBanner
            v-if="createSummaryMessage"
            :message="createSummaryMessage"
            :errors="createFieldErrors"
          />
          <p
            v-if="branchesManager.createSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ branchesManager.createSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="branchesManager.isCreateSaving"
            >
              {{ branchesManager.isCreateSaving ? 'Сохраняем…' : 'Создать филиал' }}
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
      </template>

      <template v-else-if="branchesManager.selectedBranch">
        <div class="branches-detail__header">
          <div class="branches-detail__copy">
            <p class="branches-detail__eyebrow">Код: {{ branchesManager.selectedBranch.id }}</p>
            <div class="branches-detail__title-row">
              <h2>{{ branchesManager.selectedBranch.name }}</h2>
              <StatusBadge
                :label="branchesManager.selectedBranch.isActive ? 'Активен' : 'Неактивен'"
                :tone="branchesManager.selectedBranch.isActive ? 'closed' : 'neutral'"
              />
            </div>
            <p class="branches-detail__summary">
              {{ branchesManager.selectedBranch.city }} ·
              {{ branchesManager.selectedBranch.shortLabel }}
            </p>
          </div>
        </div>

        <form
          ref="branchFormRef"
          class="admin-form-stack"
          novalidate
          @submit.prevent="handleBranchSave"
        >
          <div class="admin-section-heading">
            <h3>Основные данные</h3>
          </div>

          <div class="branches-form-grid">
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(branchFieldErrors.slug) }"
              data-field="slug"
            >
              <span class="admin-field__label">Служебный код</span>
              <input
                v-model="branchesManager.branchForm.slug"
                name="slug"
                class="admin-control"
                @input="clearBranchFieldError('slug')"
              />
              <p v-if="branchFieldErrors.slug" class="admin-field__error">
                {{ branchFieldErrors.slug }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(branchFieldErrors.shortLabel) }"
              data-field="shortLabel"
            >
              <span class="admin-field__label">Короткая подпись</span>
              <input
                v-model="branchesManager.branchForm.shortLabel"
                name="shortLabel"
                class="admin-control"
                @input="clearBranchFieldError('shortLabel')"
              />
              <p v-if="branchFieldErrors.shortLabel" class="admin-field__error">
                {{ branchFieldErrors.shortLabel }}
              </p>
            </label>
            <label
              class="admin-field branches-form-grid__full"
              :class="{ 'admin-field--error': Boolean(branchFieldErrors.name) }"
              data-field="name"
            >
              <span class="admin-field__label">Название филиала</span>
              <input
                v-model="branchesManager.branchForm.name"
                name="name"
                class="admin-control"
                @input="clearBranchFieldError('name')"
              />
              <p v-if="branchFieldErrors.name" class="admin-field__error">
                {{ branchFieldErrors.name }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(branchFieldErrors.city) }"
              data-field="city"
            >
              <span class="admin-field__label">Город</span>
              <input
                v-model="branchesManager.branchForm.city"
                name="city"
                class="admin-control"
                @input="clearBranchFieldError('city')"
              />
              <p v-if="branchFieldErrors.city" class="admin-field__error">
                {{ branchFieldErrors.city }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(branchFieldErrors.workingHours) }"
              data-field="workingHours"
            >
              <span class="admin-field__label">Режим работы</span>
              <input
                v-model="branchesManager.branchForm.workingHours"
                name="workingHours"
                class="admin-control"
                @input="clearBranchFieldError('workingHours')"
              />
              <p v-if="branchFieldErrors.workingHours" class="admin-field__error">
                {{ branchFieldErrors.workingHours }}
              </p>
            </label>
            <label
              class="admin-field branches-form-grid__full"
              :class="{ 'admin-field--error': Boolean(branchFieldErrors.description) }"
              data-field="description"
            >
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="branchesManager.branchForm.description"
                name="description"
                class="admin-control admin-control--textarea"
                @input="clearBranchFieldError('description')"
              ></textarea>
              <p v-if="branchFieldErrors.description" class="admin-field__error">
                {{ branchFieldErrors.description }}
              </p>
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Удобства</span>
              <textarea
                v-model="branchFacilitiesText"
                class="admin-control admin-control--textarea"
                placeholder="Каждая строка — отдельное удобство"
              ></textarea>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(branchFieldErrors.displayOrder) }"
              data-field="displayOrder"
            >
              <span class="admin-field__label">Порядок</span>
              <input
                v-model.number="branchesManager.branchForm.displayOrder"
                name="displayOrder"
                min="0"
                type="number"
                class="admin-control"
                @input="clearBranchFieldError('displayOrder')"
              />
              <p v-if="branchFieldErrors.displayOrder" class="admin-field__error">
                {{ branchFieldErrors.displayOrder }}
              </p>
            </label>
          </div>

          <AdminSwitchField
            v-model="branchIsActive"
            label="Филиал активен"
            hint="Неактивный филиал скрывается из мобильного приложения."
          />

          <AdminFormErrorBanner
            v-if="branchSummaryMessage"
            :message="branchSummaryMessage"
            :errors="branchFieldErrors"
          />
          <p
            v-if="branchesManager.branchSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ branchesManager.branchSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="branchesManager.isBranchSaving"
            >
              {{ branchesManager.isBranchSaving ? 'Сохраняем…' : 'Сохранить данные' }}
            </button>
          </AdminStickyActions>
        </form>

        <form
          ref="contactsFormRef"
          class="admin-form-stack"
          novalidate
          @submit.prevent="handleContactsSave"
        >
          <div class="admin-section-heading">
            <h3>Контакты и маршрут</h3>
          </div>

          <div class="branches-form-grid">
            <label
              class="admin-field branches-form-grid__full"
              :class="{ 'admin-field--error': Boolean(contactsFieldErrors.address) }"
              data-field="address"
            >
              <span class="admin-field__label">Адрес</span>
              <input
                v-model="branchesManager.contactsForm.address"
                name="address"
                class="admin-control"
                @input="clearContactsFieldError('address')"
              />
              <p v-if="contactsFieldErrors.address" class="admin-field__error">
                {{ contactsFieldErrors.address }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(contactsFieldErrors.phone) }"
              data-field="phone"
            >
              <span class="admin-field__label">Телефон</span>
              <input
                v-model="branchesManager.contactsForm.phone"
                name="phone"
                class="admin-control"
                @input="clearContactsFieldError('phone')"
              />
              <p v-if="contactsFieldErrors.phone" class="admin-field__error">
                {{ contactsFieldErrors.phone }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(contactsFieldErrors.whatsappPhone) }"
              data-field="whatsappPhone"
            >
              <span class="admin-field__label">WhatsApp</span>
              <input
                v-model="branchesManager.contactsForm.whatsappPhone"
                name="whatsappPhone"
                class="admin-control"
                @input="clearContactsFieldError('whatsappPhone')"
              />
              <p v-if="contactsFieldErrors.whatsappPhone" class="admin-field__error">
                {{ contactsFieldErrors.whatsappPhone }}
              </p>
            </label>
            <label
              class="admin-field branches-form-grid__full"
              :class="{ 'admin-field--error': Boolean(contactsFieldErrors.mapUrl) }"
              data-field="mapUrl"
            >
              <span class="admin-field__label">Ссылка на карту</span>
              <input
                v-model="branchesManager.contactsForm.mapUrl"
                name="mapUrl"
                class="admin-control"
                @input="clearContactsFieldError('mapUrl')"
              />
              <p v-if="contactsFieldErrors.mapUrl" class="admin-field__error">
                {{ contactsFieldErrors.mapUrl }}
              </p>
            </label>
            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(contactsFieldErrors.routeLabel) }"
              data-field="routeLabel"
            >
              <span class="admin-field__label">Подпись маршрута</span>
              <input
                v-model="branchesManager.contactsForm.routeLabel"
                name="routeLabel"
                class="admin-control"
                @input="clearContactsFieldError('routeLabel')"
              />
              <p v-if="contactsFieldErrors.routeLabel" class="admin-field__error">
                {{ contactsFieldErrors.routeLabel }}
              </p>
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Подсказка по парковке</span>
              <textarea
                v-model="branchesManager.contactsForm.parkingHint"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Подсказка по входу</span>
              <textarea
                v-model="branchesManager.contactsForm.arrivalHint"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>
          </div>

          <AdminFormErrorBanner
            v-if="contactsSummaryMessage"
            :message="contactsSummaryMessage"
            :errors="contactsFieldErrors"
          />
          <p
            v-if="branchesManager.contactsSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ branchesManager.contactsSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="branchesManager.isContactsSaving"
            >
              {{ branchesManager.isContactsSaving ? 'Сохраняем…' : 'Сохранить контакты' }}
            </button>
          </AdminStickyActions>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите филиал"
        description="Откройте карточку филиала, чтобы изменить данные и контакты."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';

import { useAdminBranches } from '@/features/branches/model/useAdminBranches';
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
  validateRequiredPhone,
  validateRequiredText,
  validateRequiredUrl,
} from '@/shared/lib/adminFormValidation';
import { parseTextList, stringifyTextList } from '@/shared/lib/textList';
import AdminFormErrorBanner from '@/shared/ui/AdminFormErrorBanner.vue';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminStickyActions from '@/shared/ui/AdminStickyActions.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const branchesManager = reactive(useAdminBranches());
const mobileView = ref<'list' | 'detail'>('list');
const createFormRef = ref<HTMLFormElement | null>(null);
const branchFormRef = ref<HTMLFormElement | null>(null);
const contactsFormRef = ref<HTMLFormElement | null>(null);
const createSummaryMessage = ref('');
const branchSummaryMessage = ref('');
const contactsSummaryMessage = ref('');
const createFieldErrors = reactive<AdminFieldErrors>({});
const branchFieldErrors = reactive<AdminFieldErrors>({});
const contactsFieldErrors = reactive<AdminFieldErrors>({});

const statusOptions = [
  { label: 'Все статусы', value: 'all' },
  { label: 'Активные', value: 'active' },
  { label: 'Неактивные', value: 'inactive' },
];

const createFacilitiesText = computed({
  get() {
    return stringifyTextList(branchesManager.createForm.facilities);
  },
  set(value: string) {
    branchesManager.createForm.facilities = parseTextList(value);
  },
});

const branchFacilitiesText = computed({
  get() {
    return stringifyTextList(branchesManager.branchForm.facilities ?? []);
  },
  set(value: string) {
    branchesManager.branchForm.facilities = parseTextList(value);
  },
});

const branchIsActive = computed({
  get() {
    return Boolean(branchesManager.branchForm.isActive);
  },
  set(value: boolean) {
    branchesManager.branchForm.isActive = value;
  },
});

const detailPanelTitle = computed(() => {
  if (branchesManager.isCreating) {
    return 'Новый филиал';
  }

  return branchesManager.selectedBranch?.name || 'Карточка филиала';
});

onMounted(() => {
  void branchesManager.initialize();
});

function handleStartCreate() {
  clearBranchFormFeedback();
  branchesManager.startCreate();
  mobileView.value = 'detail';
}

async function handleSelectBranch(branchId: string) {
  await branchesManager.selectBranch(branchId);
  mobileView.value = 'detail';
}

function handleBack() {
  if (branchesManager.isCreating) {
    branchesManager.cancelCreate();
  }

  clearBranchFormFeedback();
  mobileView.value = 'list';
}

async function handleCreateSubmit() {
  const errors: AdminFieldErrors = {
    slug: validateRequiredText(
      branchesManager.createForm.slug,
      'Введите служебный код филиала.',
      2,
    ),
    shortLabel: validateRequiredText(
      branchesManager.createForm.shortLabel,
      'Введите короткую подпись.',
      2,
    ),
    name: validateRequiredText(
      branchesManager.createForm.name,
      'Введите название филиала.',
      2,
    ),
    city: validateRequiredText(branchesManager.createForm.city, 'Введите город.', 2),
    workingHours: validateRequiredText(
      branchesManager.createForm.workingHours,
      'Введите режим работы.',
      2,
    ),
    address: validateRequiredText(
      branchesManager.createForm.address,
      'Введите адрес филиала.',
      4,
    ),
    phone: validateRequiredPhone(
      branchesManager.createForm.phone,
      'Введите номер телефона.',
      'Введите корректный номер телефона.',
    ),
    whatsappPhone: validateRequiredPhone(
      branchesManager.createForm.whatsappPhone,
      'Введите номер WhatsApp.',
      'Введите корректный номер WhatsApp.',
    ),
    description: validateRequiredText(
      branchesManager.createForm.description,
      'Добавьте описание филиала.',
      10,
    ),
    displayOrder: validateNonNegativeNumber(
      branchesManager.createForm.displayOrder,
      'Введите порядок не меньше 0.',
    ),
  };

  replaceFieldErrors(createFieldErrors, compactErrors(errors));
  createSummaryMessage.value = Object.keys(createFieldErrors).length
    ? 'Проверьте обязательные поля.'
    : '';

  if (Object.keys(createFieldErrors).length > 0) {
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
    return;
  }

  try {
    createSummaryMessage.value = '';
    await branchesManager.saveCreate();
  } catch (error) {
    replaceFieldErrors(createFieldErrors, resolveAdminApiFieldErrors(error));
    createSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось создать филиал.',
    );
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
  }
}

async function handleBranchSave() {
  const errors: AdminFieldErrors = {
    slug: validateRequiredText(branchesManager.branchForm.slug || '', 'Введите служебный код филиала.', 2),
    shortLabel: validateRequiredText(
      branchesManager.branchForm.shortLabel || '',
      'Введите короткую подпись.',
      2,
    ),
    name: validateRequiredText(branchesManager.branchForm.name || '', 'Введите название филиала.', 2),
    city: validateRequiredText(branchesManager.branchForm.city || '', 'Введите город.', 2),
    workingHours: validateRequiredText(
      branchesManager.branchForm.workingHours || '',
      'Введите режим работы.',
      2,
    ),
    description: validateRequiredText(
      branchesManager.branchForm.description || '',
      'Добавьте описание филиала.',
      10,
    ),
    displayOrder: validateNonNegativeNumber(
      branchesManager.branchForm.displayOrder ?? 0,
      'Введите порядок не меньше 0.',
    ),
  };

  replaceFieldErrors(branchFieldErrors, compactErrors(errors));
  branchSummaryMessage.value = Object.keys(branchFieldErrors).length
    ? 'Проверьте обязательные поля.'
    : '';

  if (Object.keys(branchFieldErrors).length > 0) {
    await focusFirstFieldError(branchFormRef.value, branchFieldErrors);
    return;
  }

  try {
    branchSummaryMessage.value = '';
    await branchesManager.saveBranch();
  } catch (error) {
    replaceFieldErrors(branchFieldErrors, resolveAdminApiFieldErrors(error));
    branchSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось сохранить филиал.',
    );
    await focusFirstFieldError(branchFormRef.value, branchFieldErrors);
  }
}

async function handleContactsSave() {
  const errors: AdminFieldErrors = {
    address: validateRequiredText(branchesManager.contactsForm.address, 'Введите адрес филиала.', 4),
    phone: validateRequiredPhone(
      branchesManager.contactsForm.phone,
      'Введите номер телефона.',
      'Введите корректный номер телефона.',
    ),
    whatsappPhone: validateRequiredPhone(
      branchesManager.contactsForm.whatsappPhone,
      'Введите номер WhatsApp.',
      'Введите корректный номер WhatsApp.',
    ),
    mapUrl: validateRequiredUrl(
      branchesManager.contactsForm.mapUrl,
      'Добавьте ссылку на карту.',
      'Введите корректную ссылку на карту.',
    ),
    routeLabel: validateRequiredText(
      branchesManager.contactsForm.routeLabel,
      'Введите подпись маршрута.',
      2,
    ),
  };

  replaceFieldErrors(contactsFieldErrors, compactErrors(errors));
  contactsSummaryMessage.value = Object.keys(contactsFieldErrors).length
    ? 'Проверьте обязательные поля.'
    : '';

  if (Object.keys(contactsFieldErrors).length > 0) {
    await focusFirstFieldError(contactsFormRef.value, contactsFieldErrors);
    return;
  }

  try {
    contactsSummaryMessage.value = '';
    await branchesManager.saveContacts();
  } catch (error) {
    replaceFieldErrors(contactsFieldErrors, resolveAdminApiFieldErrors(error));
    contactsSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось сохранить контакты филиала.',
    );
    await focusFirstFieldError(contactsFormRef.value, contactsFieldErrors);
  }
}

function clearCreateFieldError(field: string) {
  clearFieldError(createFieldErrors, field);
  if (Object.keys(createFieldErrors).length === 0) {
    createSummaryMessage.value = '';
  }
}

function clearBranchFieldError(field: string) {
  clearFieldError(branchFieldErrors, field);
  if (Object.keys(branchFieldErrors).length === 0) {
    branchSummaryMessage.value = '';
  }
}

function clearContactsFieldError(field: string) {
  clearFieldError(contactsFieldErrors, field);
  if (Object.keys(contactsFieldErrors).length === 0) {
    contactsSummaryMessage.value = '';
  }
}

function clearBranchFormFeedback() {
  replaceFieldErrors(createFieldErrors, {});
  replaceFieldErrors(branchFieldErrors, {});
  replaceFieldErrors(contactsFieldErrors, {});
  createSummaryMessage.value = '';
  branchSummaryMessage.value = '';
  contactsSummaryMessage.value = '';
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
.branches-list__filters,
.branches-list__items,
.admin-form-stack {
  display: grid;
  gap: 12px;
}

.branches-list__item {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  min-height: 68px;
  padding: 12px 14px 12px 16px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  text-align: left;
  cursor: pointer;
}

.branches-list__item:hover {
  background: var(--color-surface-subtle);
}

.branches-list__item--active {
  border-color: rgba(208, 47, 112, 0.24);
  background: #fffafd;
  box-shadow: 0 8px 20px rgba(208, 47, 112, 0.08);
}

.branches-list__item-accent {
  position: absolute;
  inset: 10px auto 10px 0;
  width: 3px;
  border-radius: 999px;
  background: transparent;
}

.branches-list__item--active .branches-list__item-accent {
  background: var(--color-accent);
}

.branches-list__item-copy {
  display: grid;
  gap: 2px;
}

.branches-list__item-copy strong,
.branches-list__item-copy p,
.branches-list__item-copy span {
  margin: 0;
}

.branches-list__item-copy p,
.branches-list__item-copy span,
.branches-detail__eyebrow,
.branches-detail__summary {
  color: var(--color-muted);
}

.branches-detail__header,
.branches-detail__copy {
  display: grid;
  gap: 6px;
}

.branches-detail__title-row {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.branches-detail__title-row h2 {
  margin: 0;
  font-size: 24px;
}

.branches-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.branches-form-grid__full {
  grid-column: 1 / -1;
}

@media (max-width: 900px) {
  .branches-form-grid {
    grid-template-columns: 1fr;
  }
}
</style>
