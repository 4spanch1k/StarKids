<template>
  <AdminCrudWorkspace
    eyebrow="Акции"
    title="Акции"
    description="Публикация офферов, филиалы показа и управление коммерческими сценариями."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--primary"
        @click="promotionsManager.startCreate"
      >
        Добавить акцию
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Список акций</h2>
        <p>Слева — очередь офферов, справа — редактирование, публикация и выключение без лишних переходов.</p>
      </div>

      <div class="admin-crud-filters">
        <AdminSearchField
          v-model="promotionsManager.searchQuery"
          placeholder="Найти акцию по названию или бейджу"
        />

        <div class="promotions-page__filter-grid">
          <AppSelectField
            v-model="promotionsManager.branchFilter"
            label="Филиал"
            :options="branchFilterOptions"
            :disabled="promotionsManager.isBranchesLoading"
          />

          <AppSelectField
            v-model="promotionsManager.activeFilter"
            label="Состояние"
            :options="activeFilterOptions"
          />

          <AppSelectField
            v-model="promotionsManager.publicationFilter"
            label="Публикация"
            :options="publicationFilterOptions"
          />
        </div>
      </div>

      <p
        v-if="promotionsManager.branchesErrorMessage"
        class="admin-inline-message admin-inline-message--error"
      >
        {{ promotionsManager.branchesErrorMessage }}
      </p>

      <StatePanel
        v-if="promotionsManager.isListLoading"
        title="Загружаем акции"
        description="Подождите немного, список обновляется с сервера."
      />

      <StatePanel
        v-else-if="promotionsManager.listErrorMessage"
        title="Не удалось открыть акции"
        :description="promotionsManager.listErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="promotionsManager.loadPromotions"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <StatePanel
        v-else-if="promotionsManager.filteredPromotions.length === 0"
        title="Акции не найдены"
        description="Проверьте фильтры или создайте новый оффер."
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--primary"
            @click="promotionsManager.startCreate"
          >
            Добавить акцию
          </button>
        </template>
      </StatePanel>

      <div v-else class="admin-list-records">
        <button
          v-for="promotion in promotionsManager.filteredPromotions"
          :key="promotion.id"
          type="button"
          class="admin-list-record"
          :class="{
            'admin-list-record--active': promotion.id === promotionsManager.selectedPromotionId,
          }"
          @click="promotionsManager.selectPromotion(promotion.id)"
        >
          <span class="admin-list-record__accent" aria-hidden="true"></span>

          <div class="admin-list-record__copy">
            <strong>{{ promotion.title }}</strong>
            <p>{{ promotion.badgeLabel || 'Без бейджа' }}</p>
            <span>{{ promotionScopeLabel(promotion.branchIds) }}</span>
          </div>

          <StatusBadge
            :label="resolvePublicationStatus(promotion).label"
            :tone="resolvePublicationStatus(promotion).tone"
          />
        </button>
      </div>
    </template>

    <template #detail>
      <StatePanel
        v-if="promotionsManager.isCreating"
        title="Новая акция"
        description="Создайте оффер, выберите филиалы показа и задайте понятный CTA."
      />

      <StatePanel
        v-else-if="promotionsManager.isDetailLoading"
        title="Открываем акцию"
        description="Подтягиваем описание, филиалы и статус публикации."
      />

      <StatePanel
        v-else-if="promotionsManager.detailErrorMessage"
        title="Не удалось открыть акцию"
        :description="promotionsManager.detailErrorMessage"
        tone="error"
      />

      <form
        v-if="promotionsManager.isCreating"
        class="admin-form-stack"
        @submit.prevent="promotionsManager.saveCreate"
      >
        <div class="admin-section-heading">
          <h2>Создать акцию</h2>
          <p>Заполните оффер и выберите, где он должен появиться в клиентском приложении.</p>
        </div>

        <div class="admin-form-grid--two">
          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Название акции</span>
            <input
              v-model="promotionsManager.createForm.title"
              required
              class="admin-control"
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Бейдж</span>
            <input
              v-model="promotionsManager.createForm.badgeLabel"
              class="admin-control"
              placeholder="Например, Новинка"
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Текст кнопки</span>
            <input
              v-model="promotionsManager.createForm.ctaLabel"
              required
              class="admin-control"
              placeholder="Оставить заявку"
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Порядок показа</span>
            <input
              v-model.number="promotionsManager.createForm.displayOrder"
              min="0"
              type="number"
              class="admin-control"
            />
          </label>

          <label class="admin-field">
            <span class="admin-field__label">Ссылка на изображение</span>
            <input
              v-model="promotionsManager.createForm.imageUrl"
              class="admin-control"
              placeholder="https://..."
            />
          </label>

          <label class="admin-field admin-field--full">
            <span class="admin-field__label">Описание</span>
            <textarea
              v-model="promotionsManager.createForm.description"
              class="admin-control admin-control--textarea"
            ></textarea>
          </label>
        </div>

        <section class="admin-panel admin-panel--stack admin-panel--muted">
          <div class="admin-section-heading">
            <h3>Филиалы показа</h3>
            <p>Если ничего не выбрано, акция будет считаться общей и может показываться во всех филиалах.</p>
          </div>

          <div class="admin-checkbox-grid">
            <label
              v-for="branch in promotionsManager.branchOptions"
              :key="branch.id"
              class="admin-checkbox-card"
            >
              <input
                v-model="promotionsManager.createForm.branchIds"
                type="checkbox"
                :value="branch.id"
              />
              <span>
                <strong>{{ branch.name }}</strong>
                <span>{{ branch.city }} · {{ branch.shortLabel }}</span>
              </span>
            </label>
          </div>
        </section>

        <div class="promotions-page__switches">
          <AdminSwitchField
            v-model="promotionsManager.createForm.isPublished"
            label="Опубликовать в приложении"
            hint="Выключите, если оффер еще готовится к запуску."
          />
          <AdminSwitchField
            v-model="promotionsManager.createForm.isActive"
            label="Акция активна"
            hint="Выключенная акция не будет показываться даже при публикации."
          />
        </div>

        <p
          v-if="promotionsManager.createErrorMessage"
          class="admin-inline-message admin-inline-message--error"
        >
          {{ promotionsManager.createErrorMessage }}
        </p>
        <p
          v-if="promotionsManager.createSuccessMessage"
          class="admin-inline-message admin-inline-message--success"
        >
          {{ promotionsManager.createSuccessMessage }}
        </p>

        <div class="admin-form-actions">
          <button
            type="submit"
            class="admin-button admin-button--primary"
            :disabled="promotionsManager.isCreateSaving"
          >
            {{ promotionsManager.isCreateSaving ? 'Сохраняем…' : 'Создать акцию' }}
          </button>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="promotionsManager.cancelCreate"
          >
            Отменить
          </button>
        </div>
      </form>

      <template v-else-if="promotionsManager.selectedPromotion">
        <header class="admin-detail-header">
          <div class="admin-detail-header__copy">
            <p class="admin-detail-header__eyebrow">
              Код: {{ promotionsManager.selectedPromotion.id }}
            </p>
            <div class="admin-detail-header__title-row">
              <h2>{{ promotionsManager.selectedPromotion.title }}</h2>
              <StatusBadge
                :label="resolvePublicationStatus(promotionsManager.selectedPromotion).label"
                :tone="resolvePublicationStatus(promotionsManager.selectedPromotion).tone"
              />
            </div>
            <p class="admin-detail-header__summary">
              {{ promotionScopeLabel(promotionsManager.selectedPromotion.branchIds) }}
            </p>
          </div>
        </header>

        <form class="admin-form-stack" @submit.prevent="promotionsManager.save">
          <div class="admin-section-heading">
            <h3>Оффер и публикация</h3>
            <p>Редактируйте оффер, набор филиалов и состояние публикации без отдельного мастера.</p>
          </div>

          <div class="admin-form-grid--two">
            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Название акции</span>
              <input
                v-model="promotionsManager.form.title"
                required
                class="admin-control"
              />
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Бейдж</span>
              <input
                v-model="promotionsManager.form.badgeLabel"
                class="admin-control"
                placeholder="Например, Новинка"
              />
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Текст кнопки</span>
              <input
                v-model="promotionsManager.form.ctaLabel"
                required
                class="admin-control"
              />
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Порядок показа</span>
              <input
                v-model.number="promotionsManager.form.displayOrder"
                min="0"
                type="number"
                class="admin-control"
              />
            </label>

            <label class="admin-field">
              <span class="admin-field__label">Ссылка на изображение</span>
              <input
                v-model="promotionsManager.form.imageUrl"
                class="admin-control"
                placeholder="https://..."
              />
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="promotionsManager.form.description"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>
          </div>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Филиалы показа</h3>
              <p>Оставьте список пустым, если акция должна считаться общей.</p>
            </div>

            <div class="admin-checkbox-grid">
              <label
                v-for="branch in promotionsManager.branchOptions"
                :key="branch.id"
                class="admin-checkbox-card"
              >
                <input
                  v-model="promotionBranchIds"
                  type="checkbox"
                  :value="branch.id"
                />
                <span>
                  <strong>{{ branch.name }}</strong>
                  <span>{{ branch.city }} · {{ branch.shortLabel }}</span>
                </span>
              </label>
            </div>
          </section>

          <div class="promotions-page__switches">
            <AdminSwitchField
              v-model="promotionIsPublished"
              label="Опубликовать в приложении"
              hint="Включите, когда оффер готов к показу пользователям."
            />
            <AdminSwitchField
              v-model="promotionIsActive"
              label="Акция активна"
              hint="Выключенная акция снимается с показа без удаления."
            />
          </div>

          <p
            v-if="promotionsManager.saveErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ promotionsManager.saveErrorMessage }}
          </p>
          <p
            v-if="promotionsManager.saveSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ promotionsManager.saveSuccessMessage }}
          </p>

          <div class="admin-form-actions">
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="promotionsManager.isSaving"
            >
              {{ promotionsManager.isSaving ? 'Сохраняем…' : 'Сохранить акцию' }}
            </button>
          </div>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите акцию слева"
        description="Детали оффера, филиалы показа и действия по публикации откроются здесь."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive } from 'vue';

import { useAdminPromotions } from '@/features/promotions/model/useAdminPromotions';
import { resolvePublicationStatus } from '@/shared/lib/adminStatus';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const promotionsManager = reactive(useAdminPromotions());

const activeFilterOptions = [
  { label: 'Все состояния', value: 'all' },
  { label: 'Активные', value: 'active' },
  { label: 'Выключенные', value: 'inactive' },
];

const publicationFilterOptions = [
  { label: 'Любая публикация', value: 'all' },
  { label: 'Опубликованные', value: 'published' },
  { label: 'Черновики', value: 'draft' },
];

const branchFilterOptions = computed(() => {
  return [
    { label: 'Все филиалы', value: '' },
    ...promotionsManager.branchOptions.map((branch) => ({
      value: branch.id,
      label: `${branch.name} · ${branch.city}`,
    })),
  ];
});

const branchNameMap = computed(() => {
  return new Map(
    promotionsManager.branchOptions.map((branch) => [branch.id, branch.name]),
  );
});

const promotionBranchIds = computed({
  get() {
    return promotionsManager.form.branchIds ?? [];
  },
  set(value: string[]) {
    promotionsManager.form.branchIds = value;
  },
});

const promotionIsActive = computed({
  get() {
    return Boolean(promotionsManager.form.isActive);
  },
  set(value: boolean) {
    promotionsManager.form.isActive = value;
  },
});

const promotionIsPublished = computed({
  get() {
    return Boolean(promotionsManager.form.isPublished);
  },
  set(value: boolean) {
    promotionsManager.form.isPublished = value;
  },
});

function promotionScopeLabel(branchIds: string[]): string {
  if (branchIds.length === 0) {
    return 'Все филиалы';
  }

  return branchIds
    .map((branchId) => branchNameMap.value.get(branchId) ?? 'Неизвестный филиал')
    .join(', ');
}

onMounted(() => {
  void promotionsManager.initialize();
});
</script>

<style scoped>
.promotions-page__filter-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.promotions-page__switches {
  display: grid;
  gap: 8px;
}

@media (max-width: 960px) {
  .promotions-page__filter-grid {
    grid-template-columns: 1fr;
  }
}
</style>
