<template>
  <AdminCrudWorkspace
    eyebrow="Коммерческое предложение"
    title="Пакеты дней рождения"
    description="Состав пакетов, цены, вместимость и доступность по филиалам."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--primary"
        @click="packagesManager.startCreate"
      >
        Добавить пакет
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Список пакетов</h2>
        <p>Слева — актуальное предложение по филиалам. Справа — создание и редактирование выбранного пакета.</p>
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
        title="Пакетов пока нет"
        description="Проверьте фильтры или создайте новый пакет для выбранного филиала."
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--primary"
            @click="packagesManager.startCreate"
          >
            Добавить пакет
          </button>
        </template>
      </StatePanel>

      <div v-else class="admin-list-records">
        <button
          v-for="item in packagesManager.filteredPackages"
          :key="item.id"
          type="button"
          class="admin-list-record"
          :class="{
            'admin-list-record--active': item.id === packagesManager.selectedPackageId,
          }"
          @click="packagesManager.selectPackage(item.id)"
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
        description="Создайте коммерческое предложение для мобильного приложения и операторов."
      />

      <StatePanel
        v-else-if="packagesManager.isDetailLoading"
        title="Открываем пакет"
        description="Подтягиваем описание, параметры и текущее состояние публикации."
      />

      <StatePanel
        v-else-if="packagesManager.detailErrorMessage"
        title="Не удалось открыть пакет"
        :description="packagesManager.detailErrorMessage"
        tone="error"
      />

      <form
        v-if="packagesManager.isCreating"
        class="admin-form-stack"
        @submit.prevent="packagesManager.saveCreate"
      >
        <div class="admin-section-heading">
          <h2>Создать пакет</h2>
          <p>Сначала заполните базовое предложение. Позже его можно дополнить без смены структуры.</p>
        </div>

        <div class="admin-form-grid--two">
          <AppSelectField
            v-model="packagesManager.createForm.branchId"
            label="Филиал"
            :options="branchSelectionOptions"
            :disabled="packagesManager.isBranchesLoading"
          />

          <label class="admin-field">
            <span class="admin-field__label">Служебный код</span>
            <input
              v-model="packagesManager.createForm.slug"
              required
              class="admin-control"
            />
          </label>

          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Название пакета</span>
            <input
              v-model="packagesManager.createForm.name"
              required
              class="admin-control"
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Цена от</span>
            <input
              v-model.number="packagesManager.createForm.priceFrom"
              min="0"
              type="number"
              class="admin-control"
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Подпись цены</span>
            <input
              v-model="packagesManager.createForm.priceLabel"
              required
              class="admin-control"
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Вместимость</span>
            <input
              v-model="packagesManager.createForm.guestCapacityLabel"
              required
              class="admin-control"
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Порядок показа</span>
            <input
              v-model.number="packagesManager.createForm.displayOrder"
              min="0"
              type="number"
              class="admin-control"
            />
          </label>

          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Описание</span>
            <textarea
              v-model="packagesManager.createForm.description"
              class="admin-control admin-control--textarea"
            ></textarea>
          </label>

          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Короткие преимущества</span>
            <textarea
              v-model="createHighlightsText"
              class="admin-control admin-control--textarea"
              placeholder="Каждая строка — отдельный тезис"
            ></textarea>
          </label>

          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Ссылка на изображение</span>
            <input
              v-model="packagesManager.createForm.imageUrl"
              class="admin-control"
              placeholder="https://..."
            />
          </label>
        </div>

        <div class="birthday-packages-page__switches">
          <AdminSwitchField
            v-model="packagesManager.createForm.isFeatured"
            label="Показывать как флагманский пакет"
            hint="Используется для акцентного показа в мобильных surfaces."
          />
          <AdminSwitchField
            v-model="packagesManager.createForm.isActive"
            label="Пакет активен"
            hint="Неактивный пакет скрывается из мобильного приложения."
          />
        </div>

        <p
          v-if="packagesManager.createErrorMessage"
          class="admin-inline-message admin-inline-message--error"
        >
          {{ packagesManager.createErrorMessage }}
        </p>
        <p
          v-if="packagesManager.createSuccessMessage"
          class="admin-inline-message admin-inline-message--success"
        >
          {{ packagesManager.createSuccessMessage }}
        </p>

        <div class="admin-form-actions">
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
            @click="packagesManager.cancelCreate"
          >
            Отменить
          </button>
        </div>
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

        <form class="admin-form-stack" @submit.prevent="packagesManager.save">
          <div class="admin-section-heading">
            <h3>Основные данные</h3>
            <p>Редактируйте описание пакета, цену, визуал и порядок показа без лишних переходов.</p>
          </div>

          <div class="admin-form-grid--two">
            <AppSelectField
              v-model="packageBranchId"
              label="Филиал"
              :options="branchSelectionOptions"
              :disabled="packagesManager.isBranchesLoading"
            />

            <label class="admin-field">
              <span class="admin-field__label">Служебный код</span>
              <input
                v-model="packagesManager.form.slug"
                required
                class="admin-control"
              />
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Название пакета</span>
              <input
                v-model="packagesManager.form.name"
                required
                class="admin-control"
              />
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Цена от</span>
              <input
                v-model.number="packagesManager.form.priceFrom"
                min="0"
                type="number"
                class="admin-control"
              />
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Подпись цены</span>
              <input
                v-model="packagesManager.form.priceLabel"
                required
                class="admin-control"
              />
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Вместимость</span>
              <input
                v-model="packagesManager.form.guestCapacityLabel"
                required
                class="admin-control"
              />
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Порядок показа</span>
              <input
                v-model.number="packagesManager.form.displayOrder"
                min="0"
                type="number"
                class="admin-control"
              />
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="packagesManager.form.description"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Короткие преимущества</span>
              <textarea
                v-model="packageHighlightsText"
                class="admin-control admin-control--textarea"
                placeholder="Каждая строка — отдельный тезис"
              ></textarea>
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Ссылка на изображение</span>
              <input
                v-model="packagesManager.form.imageUrl"
                class="admin-control"
                placeholder="https://..."
              />
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
              hint="Неактивный пакет скрывается из клиентских surfaces."
            />
          </div>

          <p
            v-if="packagesManager.saveErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ packagesManager.saveErrorMessage }}
          </p>
          <p
            v-if="packagesManager.saveSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ packagesManager.saveSuccessMessage }}
          </p>

          <div class="admin-form-actions">
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="packagesManager.isSaving"
            >
              {{ packagesManager.isSaving ? 'Сохраняем…' : 'Сохранить пакет' }}
            </button>
          </div>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите пакет слева"
        description="Подробности пакета и рабочие действия откроются здесь."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive } from 'vue';

import { useAdminBirthdayPackages } from '@/features/birthday-packages/model/useAdminBirthdayPackages';
import { resolveActiveStatus } from '@/shared/lib/adminStatus';
import { parseTextList, stringifyTextList } from '@/shared/lib/textList';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const packagesManager = reactive(useAdminBirthdayPackages());

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

function branchLabel(branchId: string): string {
  return branchNameMap.value.get(branchId) ?? 'Филиал не найден';
}

onMounted(() => {
  void packagesManager.initialize();
});
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
