<template>
  <AdminCrudWorkspace
    eyebrow="Справочный контент"
    title="Частые вопросы"
    description="Рабочий FAQ для мобильного приложения и операторов."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--primary"
        @click="faqManager.startCreate"
      >
        Добавить вопрос
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Список вопросов</h2>
        <p>Слева — текущие записи, справа — редактирование ответа и управление публикацией.</p>
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
        description="Проверьте фильтры или создайте первую запись."
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--primary"
            @click="faqManager.startCreate"
          >
            Добавить вопрос
          </button>
        </template>
      </StatePanel>

      <div v-else class="admin-list-records">
        <button
          v-for="faq in faqManager.filteredFaqs"
          :key="faq.id"
          type="button"
          class="admin-list-record"
          :class="{ 'admin-list-record--active': faq.id === faqManager.selectedFaqId }"
          @click="faqManager.selectFaq(faq.id)"
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
        description="Создайте запись, чтобы пользователи и операторы быстрее находили ответ."
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
        class="admin-form-stack"
        @submit.prevent="faqManager.saveCreate"
      >
        <div class="admin-section-heading">
          <h2>Создать вопрос</h2>
          <p>Держите формулировки короткими и понятными для родителя.</p>
        </div>

        <div class="admin-form-grid--two">
          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Вопрос</span>
            <input
              v-model="faqManager.createForm.question"
              required
              class="admin-control"
            />
          </label>

          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Ответ</span>
            <textarea
              v-model="faqManager.createForm.answer"
              class="admin-control admin-control--textarea"
            ></textarea>
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Порядок показа</span>
            <input
              v-model.number="faqManager.createForm.displayOrder"
              min="0"
              type="number"
              class="admin-control"
            />
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

        <p
          v-if="faqManager.createErrorMessage"
          class="admin-inline-message admin-inline-message--error"
        >
          {{ faqManager.createErrorMessage }}
        </p>
        <p
          v-if="faqManager.createSuccessMessage"
          class="admin-inline-message admin-inline-message--success"
        >
          {{ faqManager.createSuccessMessage }}
        </p>

        <div class="admin-form-actions">
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
            @click="faqManager.cancelCreate"
          >
            Отменить
          </button>
        </div>
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

        <form class="admin-form-stack" @submit.prevent="faqManager.save">
          <div class="admin-section-heading">
            <h3>Вопрос и ответ</h3>
            <p>Изменения сохраняются без выхода из списка.</p>
          </div>

          <div class="admin-form-grid--two">
            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Вопрос</span>
              <input
                v-model="faqManager.form.question"
                required
                class="admin-control"
              />
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Ответ</span>
              <textarea
                v-model="faqManager.form.answer"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Порядок показа</span>
              <input
                v-model.number="faqManager.form.displayOrder"
                min="0"
                type="number"
                class="admin-control"
              />
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

          <p
            v-if="faqManager.saveErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ faqManager.saveErrorMessage }}
          </p>
          <p
            v-if="faqManager.saveSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ faqManager.saveSuccessMessage }}
          </p>

          <div class="admin-form-actions">
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="faqManager.isSaving"
            >
              {{ faqManager.isSaving ? 'Сохраняем…' : 'Сохранить вопрос' }}
            </button>
          </div>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите вопрос слева"
        description="Ответ и параметры публикации откроются здесь."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive } from 'vue';

import { useAdminFaqs } from '@/features/content/model/useAdminFaqs';
import { resolvePublicationStatus } from '@/shared/lib/adminStatus';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const faqManager = reactive(useAdminFaqs());

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

onMounted(() => {
  void faqManager.initialize();
});
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

@media (max-width: 860px) {
  .faq-page__filter-grid {
    grid-template-columns: 1fr;
  }
}
</style>
