<template>
  <AdminCrudWorkspace
    eyebrow="Медиаданные"
    title="Галерея"
    description="Управление hero-изображением и набором gallery URL по филиалам."
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
        <p>Выберите филиал, чтобы обновить hero-изображение и метаданные галереи.</p>
      </div>

      <AdminSearchField
        v-model="searchQuery"
        placeholder="Найти филиал"
      />

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
          @click="galleryManager.selectBranch(branch.id)"
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
        v-else-if="galleryManager.galleryErrorMessage"
        title="Не удалось открыть галерею"
        :description="galleryManager.galleryErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            v-if="galleryManager.selectedBranchId"
            type="button"
            class="admin-button admin-button--secondary"
            @click="galleryManager.selectBranch(galleryManager.selectedBranchId)"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <template v-else-if="selectedBranch">
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
              Здесь хранятся только метаданные и URL. Файлы и загрузка не входят в текущий scope.
            </p>
          </div>
        </header>

        <form class="admin-form-stack" @submit.prevent="galleryManager.save">
          <div class="admin-section-heading">
            <h3>Hero и список изображений</h3>
            <p>Используйте прямые URL. Каждая строка в списке ниже — отдельное изображение галереи.</p>
          </div>

          <label class="admin-field">
            <span class="admin-field__label">Hero-изображение</span>
            <input
              v-model="galleryManager.form.heroImageUrl"
              class="admin-control"
              placeholder="https://..."
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Изображения галереи</span>
            <textarea
              v-model="galleryUrlsText"
              class="admin-control admin-control--textarea"
              placeholder="Каждая строка — отдельный URL"
            ></textarea>
          </label>

          <p
            v-if="galleryManager.successMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ galleryManager.successMessage }}
          </p>

          <div class="admin-form-actions">
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="galleryManager.isSaving"
            >
              {{ galleryManager.isSaving ? 'Сохраняем…' : 'Сохранить галерею' }}
            </button>
          </div>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите филиал слева"
        description="Hero и галерея выбранного филиала откроются здесь."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';

import { useBranchGalleryManager } from '@/features/branches/model/useBranchGalleryManager';
import { resolveActiveStatus } from '@/shared/lib/adminStatus';
import { parseTextList, stringifyTextList } from '@/shared/lib/textList';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const galleryManager = reactive(useBranchGalleryManager());
const searchQuery = ref('');

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

const galleryUrlsText = computed({
  get() {
    return stringifyTextList(galleryManager.form.galleryImageUrls);
  },
  set(value: string) {
    galleryManager.form.galleryImageUrls = parseTextList(value);
  },
});

onMounted(() => {
  void galleryManager.initialize();
});
</script>
