<template>
  <AdminCrudWorkspace
    eyebrow="Справочный контент"
    title="Частые вопросы"
    description="FAQ для мобильного приложения и операторов."
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
        Добавить вопрос
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>FAQ</h2>
      </div>

      <div class="admin-crud-filters">
        <AdminSearchField
          v-model="faqManager.searchQuery"
          placeholder="Найти вопрос"
        />

        <div class="faq-page__filter-grid">
          <AppSelectField
            v-model="faqManager.activeFilter"
            label="Состояние"
            :options="toggleFilterOptions"
          />

          <AppSelectField
            v-model="faqManager.publicationFilter"
            label="Публикация"
            :options="publicationFilterOptions"
          />
        </div>
      </div>

      <StatePanel
        v-if="faqManager.isListLoading"
        title="Загружаем FAQ"
        description="Подтягиваем список вопросов с сервера."
      />

      <StatePanel
        v-else-if="faqManager.listErrorMessage"
        title="Не удалось открыть FAQ"
        :description="faqManager.listErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="faqManager.loadFaqs"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <StatePanel
        v-else-if="faqManager.filteredFaqs.length === 0"
        title="Вопросы не найдены"
        description="Проверьте фильтры или строку поиска."
      />

      <div v-else class="admin-list-records">
        <button
          v-for="faq in faqManager.filteredFaqs"
          :key="faq.id"
          type="button"
          class="admin-list-record"
          :class="{ 'admin-list-record--active': faq.id === faqManager.selectedFaqId }"
          @click="handleSelectFaq(faq.id)"
        >
          <span class="admin-list-record__accent" aria-hidden="true"></span>
          <div class="admin-list-record__copy">
            <strong>{{ faq.question }}</strong>
            <p>{{ faq.answer }}</p>
            <span>Порядок: {{ faq.displayOrder }}</span>
          </div>
          <StatusBadge
            :label="resolvePublicationStatus(faq).label"
            :tone="resolvePublicationStatus(faq).tone"
          />
        </button>
      </div>
    </template>

    <template #detail>
      <StatePanel
        v-if="faqManager.isCreating"
        title="Новый вопрос"
        description="Создайте запись, чтобы пользователь сразу видел готовый ответ."
      />

      <StatePanel
        v-else-if="faqManager.isDetailLoading"
        title="Открываем вопрос"
        description="Подтягиваем текст ответа и статус публикации."
      />

      <StatePanel
        v-else-if="faqManager.detailErrorMessage"
        title="Не удалось открыть вопрос"
        :description="faqManager.detailErrorMessage"
        tone="error"
      />

      <form
        v-if="faqManager.isCreating"
        ref="createFormRef"
        class="admin-form-stack"
        novalidate
        @submit.prevent="handleCreateSubmit"
      >
        <div class="admin-section-heading">
          <h2>Создать вопрос</h2>
        </div>

        <div class="admin-form-grid--two">
          <label
            class="admin-field admin-field--full"
            :class="{ 'admin-field--error': Boolean(createFieldErrors.question) }"
            data-field="question"
          >
            <span class="admin-field__label">Вопрос</span>
            <input
              v-model="faqManager.createForm.question"
              name="question"
              class="admin-control"
              @input="clearCreateFieldError('question')"
            />
            <p v-if="createFieldErrors.question" class="admin-field__error">
              {{ createFieldErrors.question }}
            </p>
          </label>

          <label
            class="admin-field admin-field--full"
            :class="{ 'admin-field--error': Boolean(createFieldErrors.answer) }"
            data-field="answer"
          >
            <span class="admin-field__label">Ответ</span>
            <textarea
              v-model="faqManager.createForm.answer"
              name="answer"
              class="admin-control admin-control--textarea"
              @input="clearCreateFieldError('answer')"
            ></textarea>
            <p v-if="createFieldErrors.answer" class="admin-field__error">
              {{ createFieldErrors.answer }}
            </p>
          </label>

          <label
            class="admin-field"
            :class="{ 'admin-field--error': Boolean(createFieldErrors.displayOrder) }"
            data-field="displayOrder"
          >
            <span class="admin-field__label">Порядок показа</span>
            <input
              v-model.number="faqManager.createForm.displayOrder"
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

        <div class="faq-page__switches">
          <AdminSwitchField
            v-model="faqManager.createForm.isPublished"
            label="Опубликовать в приложении"
            hint="Черновик остается доступным только внутри админки."
          />
          <AdminSwitchField
            v-model="faqManager.createForm.isActive"
            label="Вопрос активен"
            hint="Неактивная запись скрывается из выдачи."
          />
        </div>

        <AdminFormErrorBanner
          v-if="createSummaryMessage"
          :message="createSummaryMessage"
          :errors="createFieldErrors"
        />
        <p
          v-if="faqManager.createSuccessMessage"
          class="admin-inline-message admin-inline-message--success"
        >
          {{ faqManager.createSuccessMessage }}
        </p>

        <AdminStickyActions>
          <button
            type="submit"
            class="admin-button admin-button--primary"
            :disabled="faqManager.isCreateSaving"
          >
            {{ faqManager.isCreateSaving ? 'Сохраняем…' : 'Создать вопрос' }}
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

      <template v-else-if="faqManager.selectedFaq">
        <header class="admin-detail-header">
          <div class="admin-detail-header__copy">
            <p class="admin-detail-header__eyebrow">Код: {{ faqManager.selectedFaq.id }}</p>
            <div class="admin-detail-header__title-row">
              <h2>{{ faqManager.selectedFaq.question }}</h2>
              <StatusBadge
                :label="resolvePublicationStatus(faqManager.selectedFaq).label"
                :tone="resolvePublicationStatus(faqManager.selectedFaq).tone"
              />
            </div>
            <p class="admin-detail-header__summary">
              Порядок показа: {{ faqManager.selectedFaq.displayOrder }}
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
            <h3>Вопрос и ответ</h3>
          </div>

          <div class="admin-form-grid--two">
            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.question) }"
              data-field="question"
            >
              <span class="admin-field__label">Вопрос</span>
              <input
                v-model="faqManager.form.question"
                name="question"
                class="admin-control"
                @input="clearEditFieldError('question')"
              />
              <p v-if="editFieldErrors.question" class="admin-field__error">
                {{ editFieldErrors.question }}
              </p>
            </label>

            <label
              class="admin-field admin-field--full"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.answer) }"
              data-field="answer"
            >
              <span class="admin-field__label">Ответ</span>
              <textarea
                v-model="faqManager.form.answer"
                name="answer"
                class="admin-control admin-control--textarea"
                @input="clearEditFieldError('answer')"
              ></textarea>
              <p v-if="editFieldErrors.answer" class="admin-field__error">
                {{ editFieldErrors.answer }}
              </p>
            </label>

            <label
              class="admin-field"
              :class="{ 'admin-field--error': Boolean(editFieldErrors.displayOrder) }"
              data-field="displayOrder"
            >
              <span class="admin-field__label">Порядок показа</span>
              <input
                v-model.number="faqManager.form.displayOrder"
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

          <div class="faq-page__switches">
            <AdminSwitchField
              v-model="faqIsPublished"
              label="Опубликовать в приложении"
              hint="Включите, когда ответ готов для пользователей."
            />
            <AdminSwitchField
              v-model="faqIsActive"
              label="Вопрос активен"
              hint="Выключенная запись остается в системе, но скрывается из выдачи."
            />
          </div>

          <AdminFormErrorBanner
            v-if="editSummaryMessage"
            :message="editSummaryMessage"
            :errors="editFieldErrors"
          />
          <p
            v-if="faqManager.saveSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ faqManager.saveSuccessMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="faqManager.isSaving"
            >
              {{ faqManager.isSaving ? 'Сохраняем…' : 'Сохранить вопрос' }}
            </button>
          </AdminStickyActions>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите вопрос"
        description="Откройте запись, чтобы изменить ответ и публикацию."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';

import { useAdminFaqs } from '@/features/content/model/useAdminFaqs';
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
  validateRequiredText,
} from '@/shared/lib/adminFormValidation';
import { resolvePublicationStatus } from '@/shared/lib/adminStatus';
import AdminFormErrorBanner from '@/shared/ui/AdminFormErrorBanner.vue';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminStickyActions from '@/shared/ui/AdminStickyActions.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const faqManager = reactive(useAdminFaqs());
const mobileView = ref<'list' | 'detail'>('list');
const createFormRef = ref<HTMLFormElement | null>(null);
const editFormRef = ref<HTMLFormElement | null>(null);
const createSummaryMessage = ref('');
const editSummaryMessage = ref('');
const createFieldErrors = reactive<AdminFieldErrors>({});
const editFieldErrors = reactive<AdminFieldErrors>({});

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

const faqIsActive = computed({
  get() {
    return Boolean(faqManager.form.isActive);
  },
  set(value: boolean) {
    faqManager.form.isActive = value;
  },
});

const faqIsPublished = computed({
  get() {
    return Boolean(faqManager.form.isPublished);
  },
  set(value: boolean) {
    faqManager.form.isPublished = value;
  },
});

const detailPanelTitle = computed(() => {
  if (faqManager.isCreating) {
    return 'Новый вопрос';
  }

  return faqManager.selectedFaq?.question || 'Карточка вопроса';
});

onMounted(() => {
  void faqManager.initialize();
});

function handleStartCreate() {
  clearFormFeedback();
  faqManager.startCreate();
  mobileView.value = 'detail';
}

async function handleSelectFaq(faqId: string) {
  await faqManager.selectFaq(faqId);
  mobileView.value = 'detail';
}

function handleBack() {
  if (faqManager.isCreating) {
    faqManager.cancelCreate();
  }

  clearFormFeedback();
  mobileView.value = 'list';
}

async function handleCreateSubmit() {
  const errors = compactErrors({
    question: validateRequiredText(
      faqManager.createForm.question,
      'Введите вопрос.',
      4,
    ),
    answer: validateRequiredText(
      faqManager.createForm.answer,
      'Введите ответ.',
      4,
    ),
    displayOrder: validateNonNegativeNumber(
      faqManager.createForm.displayOrder,
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
    await faqManager.saveCreate();
  } catch (error) {
    replaceFieldErrors(createFieldErrors, resolveAdminApiFieldErrors(error));
    createSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось создать вопрос.',
    );
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
  }
}

async function handleSave() {
  const errors = compactErrors({
    question: validateRequiredText(faqManager.form.question || '', 'Введите вопрос.', 4),
    answer: validateRequiredText(faqManager.form.answer || '', 'Введите ответ.', 4),
    displayOrder: validateNonNegativeNumber(
      faqManager.form.displayOrder ?? 0,
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
    await faqManager.save();
  } catch (error) {
    replaceFieldErrors(editFieldErrors, resolveAdminApiFieldErrors(error));
    editSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось сохранить вопрос.',
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
.faq-page__filter-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.faq-page__switches {
  display: grid;
  gap: 8px;
}

@media (max-width: 720px) {
  .faq-page__filter-grid {
    grid-template-columns: 1fr;
  }
}
</style>
