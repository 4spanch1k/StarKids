<template>
  <AdminCrudWorkspace
    eyebrow="Контент"
    title="Контент приложения"
    description="Тексты, CTA и порядок контентных блоков для мобильных поверхностей."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--primary"
        @click="contentBlocksManager.startCreate"
      >
        Добавить блок
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Контентные блоки</h2>
        <p>Слева — существующие блоки, справа — создание и редактирование без отдельного мастера.</p>
      </div>

      <div class="admin-crud-filters">
        <AdminSearchField
          v-model="contentBlocksManager.searchQuery"
          placeholder="Найти блок по заголовку или ключу"
        />

        <div class="content-page__filter-grid">
          <AppSelectField
            v-model="contentBlocksManager.surfaceFilter"
            label="Поверхность"
            :options="surfaceFilterOptions"
          />

          <AppSelectField
            v-model="contentBlocksManager.activeFilter"
            label="Состояние"
            :options="toggleFilterOptions"
          />

          <AppSelectField
            v-model="contentBlocksManager.publicationFilter"
            label="Публикация"
            :options="publicationFilterOptions"
          />
        </div>
      </div>

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
        description="Проверьте фильтры или создайте первый блок для нужной поверхности."
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--primary"
            @click="contentBlocksManager.startCreate"
          >
            Добавить блок
          </button>
        </template>
      </StatePanel>

      <div v-else class="admin-list-records">
        <button
          v-for="block in contentBlocksManager.filteredBlocks"
          :key="block.id"
          type="button"
          class="admin-list-record"
          :class="{ 'admin-list-record--active': block.id === contentBlocksManager.selectedBlockId }"
          @click="contentBlocksManager.selectBlock(block.id)"
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
        v-if="contentBlocksManager.isCreating"
        title="Новый контентный блок"
        description="Создайте блок и выберите поверхность, на которой он должен появиться."
      />

      <StatePanel
        v-else-if="contentBlocksManager.isDetailLoading"
        title="Открываем блок"
        description="Подтягиваем текущий текст и параметры показа."
      />

      <StatePanel
        v-else-if="contentBlocksManager.detailErrorMessage"
        title="Не удалось открыть блок"
        :description="contentBlocksManager.detailErrorMessage"
        tone="error"
      />

      <form
        v-if="contentBlocksManager.isCreating"
        class="admin-form-stack"
        @submit.prevent="contentBlocksManager.saveCreate"
      >
        <div class="admin-section-heading">
          <h2>Создать блок</h2>
          <p>Один экран — один блок. Держим форму короткой и понятной для оператора.</p>
        </div>

        <div class="admin-form-grid--two">
          <AppSelectField
            v-model="contentBlocksManager.createForm.surface"
            label="Поверхность"
            :options="surfaceSelectOptions"
          />

          <label class="admin-field">
            <span class="admin-field__label">Ключ блока</span>
            <input
              v-model="contentBlocksManager.createForm.key"
              required
              class="admin-control"
            />
          </label>

          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Заголовок</span>
            <input
              v-model="contentBlocksManager.createForm.title"
              required
              class="admin-control"
            />
          </label>

          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Текст</span>
            <textarea
              v-model="contentBlocksManager.createForm.body"
              class="admin-control admin-control--textarea"
            ></textarea>
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Текст кнопки</span>
            <input
              v-model="contentBlocksManager.createForm.ctaLabel"
              class="admin-control"
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Порядок показа</span>
            <input
              v-model.number="contentBlocksManager.createForm.displayOrder"
              min="0"
              type="number"
              class="admin-control"
            />
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

        <p
          v-if="contentBlocksManager.createErrorMessage"
          class="admin-inline-message admin-inline-message--error"
        >
          {{ contentBlocksManager.createErrorMessage }}
        </p>
        <p
          v-if="contentBlocksManager.createSuccessMessage"
          class="admin-inline-message admin-inline-message--success"
        >
          {{ contentBlocksManager.createSuccessMessage }}
        </p>

        <div class="admin-form-actions">
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
            @click="contentBlocksManager.cancelCreate"
          >
            Отменить
          </button>
        </div>
      </form>

      <template v-else-if="contentBlocksManager.selectedBlock">
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
        </header>

        <form class="admin-form-stack" @submit.prevent="contentBlocksManager.save">
          <div class="admin-section-heading">
            <h3>Текст и публикация</h3>
            <p>Правьте сам блок, порядок показа и доступность без выхода со страницы.</p>
          </div>

          <div class="admin-form-grid--two">
            <AppSelectField
              v-model="blockSurface"
              label="Поверхность"
              :options="surfaceSelectOptions"
            />

            <label class="admin-field">
              <span class="admin-field__label">Ключ блока</span>
              <input
                v-model="contentBlocksManager.form.key"
                required
                class="admin-control"
              />
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Заголовок</span>
              <input
                v-model="contentBlocksManager.form.title"
                required
                class="admin-control"
              />
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Текст</span>
              <textarea
                v-model="contentBlocksManager.form.body"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Текст кнопки</span>
              <input
                v-model="contentBlocksManager.form.ctaLabel"
                class="admin-control"
              />
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Порядок показа</span>
              <input
                v-model.number="contentBlocksManager.form.displayOrder"
                min="0"
                type="number"
                class="admin-control"
              />
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

          <p
            v-if="contentBlocksManager.saveErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ contentBlocksManager.saveErrorMessage }}
          </p>
          <p
            v-if="contentBlocksManager.saveSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ contentBlocksManager.saveSuccessMessage }}
          </p>

          <div class="admin-form-actions">
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="contentBlocksManager.isSaving"
            >
              {{ contentBlocksManager.isSaving ? 'Сохраняем…' : 'Сохранить блок' }}
            </button>
          </div>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите блок слева"
        description="Текст, порядок показа и статус публикации откроются здесь."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive } from 'vue';

import {
  contentSurfaceOptions,
  getContentSurfaceLabel,
} from '@/features/content/model/contentSurface';
import { useAdminContentBlocks } from '@/features/content/model/useAdminContentBlocks';
import { resolvePublicationStatus } from '@/shared/lib/adminStatus';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const contentBlocksManager = reactive(useAdminContentBlocks());

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
  return [
    { label: 'Все поверхности', value: '' },
    ...surfaceSelectOptions.value,
  ];
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

function contentSurfaceLabel(surface: string): string {
  return getContentSurfaceLabel(surface);
}

onMounted(() => {
  void contentBlocksManager.initialize();
});
</script>

<style scoped>
.content-page__filter-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.content-page__switches {
  display: grid;
  gap: 8px;
}

@media (max-width: 960px) {
  .content-page__filter-grid {
    grid-template-columns: 1fr;
  }
}
</style>
