<template>
  <AdminCrudWorkspace
    eyebrow="Контент филиалов"
    title="Филиалы"
    description="Список филиалов, основные параметры и контакты для мобильного приложения."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--primary"
        @click="branchesManager.startCreate"
      >
        Добавить филиал
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Список филиалов</h2>
        <p>Выберите филиал слева или создайте новый, чтобы открыть рабочую карточку.</p>
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
        description="Проверьте строку поиска или создайте новый филиал."
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--primary"
            @click="branchesManager.startCreate"
          >
            Добавить филиал
          </button>
        </template>
      </StatePanel>

      <div v-else class="branches-list__items">
        <button
          v-for="branch in branchesManager.filteredBranches"
          :key="branch.id"
          type="button"
          class="branches-list__item"
          :class="{
            'branches-list__item--active': branch.id === branchesManager.selectedBranchId,
          }"
          @click="branchesManager.selectBranch(branch.id)"
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
        <form class="admin-form-stack" @submit.prevent="branchesManager.saveCreate">
          <div class="admin-section-heading">
            <h2>Создать филиал</h2>
            <p>Эта форма создает карточку филиала и базовую контактную информацию.</p>
          </div>

          <div class="branches-form-grid">
            <label class="admin-field">
              <span class="admin-field__label">Служебный код</span>
              <input v-model="branchesManager.createForm.slug" required class="admin-control" />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Короткая подпись</span>
              <input
                v-model="branchesManager.createForm.shortLabel"
                required
                class="admin-control"
              />
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Название филиала</span>
              <input v-model="branchesManager.createForm.name" required class="admin-control" />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Город</span>
              <input v-model="branchesManager.createForm.city" required class="admin-control" />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Режим работы</span>
              <input
                v-model="branchesManager.createForm.workingHours"
                required
                class="admin-control"
              />
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Адрес</span>
              <input
                v-model="branchesManager.createForm.address"
                required
                class="admin-control"
              />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Телефон</span>
              <input
                v-model="branchesManager.createForm.phone"
                required
                class="admin-control"
              />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">WhatsApp</span>
              <input
                v-model="branchesManager.createForm.whatsappPhone"
                required
                class="admin-control"
              />
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="branchesManager.createForm.description"
                required
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Удобства</span>
              <textarea
                v-model="createFacilitiesText"
                class="admin-control admin-control--textarea"
                placeholder="Каждая строка — отдельное удобство"
              ></textarea>
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Порядок</span>
              <input
                v-model.number="branchesManager.createForm.displayOrder"
                min="0"
                type="number"
                class="admin-control"
              />
            </label>
          </div>

          <AdminSwitchField
            v-model="branchesManager.createForm.isActive"
            label="Филиал активен"
            hint="Неактивный филиал не будет виден в мобильном приложении."
          />

          <p
            v-if="branchesManager.createErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ branchesManager.createErrorMessage }}
          </p>
          <p
            v-if="branchesManager.createSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ branchesManager.createSuccessMessage }}
          </p>

          <div class="admin-form-actions">
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
              @click="branchesManager.cancelCreate"
            >
              Отменить
            </button>
          </div>
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

        <form class="admin-form-stack" @submit.prevent="branchesManager.saveBranch">
          <div class="admin-section-heading">
            <h3>Основные данные</h3>
            <p>Название, служебный код, порядок и описание филиала для операторов и мобильного приложения.</p>
          </div>

          <div class="branches-form-grid">
            <label class="admin-field">
              <span class="admin-field__label">Служебный код</span>
              <input v-model="branchesManager.branchForm.slug" required class="admin-control" />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Короткая подпись</span>
              <input
                v-model="branchesManager.branchForm.shortLabel"
                required
                class="admin-control"
              />
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Название филиала</span>
              <input v-model="branchesManager.branchForm.name" required class="admin-control" />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Город</span>
              <input v-model="branchesManager.branchForm.city" required class="admin-control" />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Режим работы</span>
              <input
                v-model="branchesManager.branchForm.workingHours"
                required
                class="admin-control"
              />
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="branchesManager.branchForm.description"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Удобства</span>
              <textarea
                v-model="branchFacilitiesText"
                class="admin-control admin-control--textarea"
                placeholder="Каждая строка — отдельное удобство"
              ></textarea>
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Порядок</span>
              <input
                v-model.number="branchesManager.branchForm.displayOrder"
                min="0"
                type="number"
                class="admin-control"
              />
            </label>
          </div>

          <AdminSwitchField
            v-model="branchIsActive"
            label="Филиал активен"
            hint="Неактивный филиал скрывается из мобильного приложения."
          />

          <p
            v-if="branchesManager.branchErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ branchesManager.branchErrorMessage }}
          </p>
          <p
            v-if="branchesManager.branchSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ branchesManager.branchSuccessMessage }}
          </p>

          <div class="admin-form-actions">
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="branchesManager.isBranchSaving"
            >
              {{ branchesManager.isBranchSaving ? 'Сохраняем…' : 'Сохранить данные' }}
            </button>
          </div>
        </form>

        <form class="admin-form-stack" @submit.prevent="branchesManager.saveContacts">
          <div class="admin-section-heading">
            <h3>Контакты и маршрут</h3>
            <p>То, что увидит родитель на экране контактов в мобильном приложении.</p>
          </div>

          <div class="branches-form-grid">
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Адрес</span>
              <input v-model="branchesManager.contactsForm.address" required class="admin-control" />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Телефон</span>
              <input v-model="branchesManager.contactsForm.phone" required class="admin-control" />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">WhatsApp</span>
              <input
                v-model="branchesManager.contactsForm.whatsappPhone"
                required
                class="admin-control"
              />
            </label>
            <label class="admin-field branches-form-grid__full">
              <span class="admin-field__label">Ссылка на карту</span>
              <input
                v-model="branchesManager.contactsForm.mapUrl"
                required
                class="admin-control"
              />
            </label>
            <label class="admin-field">
              <span class="admin-field__label">Подпись маршрута</span>
              <input
                v-model="branchesManager.contactsForm.routeLabel"
                required
                class="admin-control"
              />
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

          <p
            v-if="branchesManager.contactsErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ branchesManager.contactsErrorMessage }}
          </p>
          <p
            v-if="branchesManager.contactsSuccessMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ branchesManager.contactsSuccessMessage }}
          </p>

          <div class="admin-form-actions">
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="branchesManager.isContactsSaving"
            >
              {{ branchesManager.isContactsSaving ? 'Сохраняем…' : 'Сохранить контакты' }}
            </button>
          </div>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите филиал слева"
        description="Карточка филиала и его контакты откроются здесь."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive } from 'vue';

import { useAdminBranches } from '@/features/branches/model/useAdminBranches';
import { parseTextList, stringifyTextList } from '@/shared/lib/textList';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const branchesManager = reactive(useAdminBranches());

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

onMounted(() => {
  void branchesManager.initialize();
});
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
