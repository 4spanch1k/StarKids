<template>
  <AdminCrudWorkspace
    eyebrow="Управляемый контент"
    title="Билеты"
    description="Входные билеты и льготы по филиалам."
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
        class="admin-button admin-button--secondary"
        @click="ticketManager.initialize"
      >
        Обновить филиалы
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Филиалы</h2>
      </div>

      <AdminCompactFilters>
        <template #primary>
          <AdminSearchField v-model="searchQuery" placeholder="Найти филиал" />
        </template>
      </AdminCompactFilters>

      <StatePanel
        v-if="ticketManager.isBranchesLoading"
        title="Загружаем филиалы"
        description="Подготавливаем список филиалов для настройки билетов."
      />

      <StatePanel
        v-else-if="ticketManager.branchesErrorMessage"
        title="Не удалось загрузить филиалы"
        :description="ticketManager.branchesErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="ticketManager.initialize"
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
          :class="{ 'admin-list-record--active': branch.id === ticketManager.selectedBranchId }"
          @click="void routeState.goToDetail(branch.id)"
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
        v-if="ticketManager.isContentLoading"
        title="Открываем билеты"
        description="Подтягиваем билетную конфигурацию выбранного филиала."
      />

      <StatePanel
        v-else-if="ticketManager.contentErrorMessage && routeMode === 'detail'"
        title="Не удалось открыть билеты"
        :description="ticketManager.contentErrorMessage"
        tone="error"
      />

      <template v-else-if="selectedBranch">
        <template v-if="routeMode === 'detail'">
          <div class="tickets-detail-view">
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
                  {{ selectedBranch.city }} · {{ selectedBranch.shortLabel }}
                </p>
              </div>

              <div class="tickets-detail-view__actions">
                <button
                  type="button"
                  class="admin-button admin-button--primary"
                  @click="void routeState.goToEdit(selectedBranch.id)"
                >
                  Редактировать
                </button>
              </div>
            </header>

            <AdminSummaryList title="Сводка билетов" :items="ticketSummaryItems" />

            <AdminSummaryList title="Типы билетов" :items="itemSummaryItems">
              <ul class="tickets-detail-view__list">
                <li
                  v-for="(item, index) in sortedItems"
                  :key="item.id || `detail-item-${index}`"
                >
                  <strong>{{ item.title || `Билет ${index + 1}` }}</strong>
                  <span> · {{ formatPrice(item.priceTenge) }}</span>
                  <span> · порядок {{ item.displayOrder }}</span>
                </li>
              </ul>
            </AdminSummaryList>

            <AdminSummaryList title="Подсказки и льготы" :items="noteSummaryItems">
              <ul class="tickets-detail-view__list">
                <li
                  v-for="(note, index) in sortedNotes"
                  :key="note.id || `detail-note-${index}`"
                >
                  <strong>{{ note.text || `Подсказка ${index + 1}` }}</strong>
                  <span> · порядок {{ note.displayOrder }}</span>
                </li>
              </ul>
            </AdminSummaryList>
          </div>
        </template>

        <form v-else class="admin-form-stack" @submit.prevent="handleSave">
          <div class="admin-section-heading">
            <h2>Редактировать билеты</h2>
          </div>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Типы билетов</h3>
              <p>Название, цена, описание, порядок и видимость управляются отдельно для каждого филиала.</p>
            </div>

            <div class="admin-repeater">
              <article
                v-for="(item, index) in ticketManager.form.items"
                :key="item.id || `ticket-item-${index}`"
                class="admin-repeater__item"
              >
                <div class="admin-repeater__header">
                  <strong>{{ item.title || `Билет ${index + 1}` }}</strong>
                  <button
                    type="button"
                    class="admin-button admin-button--ghost"
                    @click="ticketManager.removeItem(index)"
                  >
                    Удалить
                  </button>
                </div>

                <div class="admin-repeater__grid">
                  <label class="admin-field">
                    <span class="admin-field__label">Название</span>
                    <input v-model="item.title" class="admin-control" />
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Цена, тг</span>
                    <input
                      v-model.number="item.priceTenge"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Порядок</span>
                    <input
                      v-model.number="item.displayOrder"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>

                  <label class="admin-field admin-field--full">
                    <span class="admin-field__label">Описание</span>
                    <textarea
                      v-model="item.description"
                      class="admin-control admin-control--textarea"
                      rows="3"
                    />
                  </label>

                  <label class="admin-field admin-field--full">
                    <span class="admin-field__label">Пометки</span>
                    <textarea
                      :value="joinBadgeLabels(item.badgeLabels)"
                      class="admin-control admin-control--textarea"
                      rows="3"
                      placeholder="Одна пометка на строку"
                      @input="updateBadgeLabels(index, ($event.target as HTMLTextAreaElement).value)"
                    />
                  </label>
                </div>

                <AdminSwitchField
                  v-model="item.isActive"
                  label="Билет активен"
                  hint="Неактивный билет не будет показан в мобильном приложении."
                />
              </article>
            </div>

            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="ticketManager.addItem"
            >
              Добавить билет
            </button>
          </section>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Подсказки и льготы</h3>
              <p>Эти строки отображаются в мобильном ticket flow как полезные условия и льготы.</p>
            </div>

            <div class="admin-repeater">
              <article
                v-for="(note, index) in ticketManager.form.notes"
                :key="note.id || `ticket-note-${index}`"
                class="admin-repeater__item"
              >
                <div class="admin-repeater__header">
                  <strong>{{ note.text || `Подсказка ${index + 1}` }}</strong>
                  <button
                    type="button"
                    class="admin-button admin-button--ghost"
                    @click="ticketManager.removeNote(index)"
                  >
                    Удалить
                  </button>
                </div>

                <div class="admin-repeater__grid">
                  <label class="admin-field admin-field--full">
                    <span class="admin-field__label">Текст</span>
                    <textarea
                      v-model="note.text"
                      class="admin-control admin-control--textarea"
                      rows="2"
                    />
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Порядок</span>
                    <input
                      v-model.number="note.displayOrder"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>
                </div>

                <AdminSwitchField
                  v-model="note.isActive"
                  label="Подсказка активна"
                  hint="Неактивная подсказка останется в админке, но пропадет из мобильного приложения."
                />
              </article>
            </div>

            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="ticketManager.addNote"
            >
              Добавить подсказку
            </button>
          </section>

          <p
            v-if="ticketManager.successMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ ticketManager.successMessage }}
          </p>
          <p
            v-if="ticketManager.contentErrorMessage"
            class="admin-inline-message admin-inline-message--error"
          >
            {{ ticketManager.contentErrorMessage }}
          </p>

          <AdminStickyActions>
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="ticketManager.isSaving"
            >
              {{ ticketManager.isSaving ? 'Сохраняем…' : 'Сохранить билеты' }}
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
        title="Выберите филиал"
        description="Откройте филиал, чтобы посмотреть или изменить билеты."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import { useBranchTicketManager } from '@/features/branches/model/useBranchTicketManager';
import type {
  AdminBranchTicketItem,
  AdminBranchTicketNote,
} from '@/features/branches/model/adminBranch';
import { resolveActiveStatus } from '@/shared/lib/adminStatus';
import { useAdminCrudRouteState } from '@/shared/composables/useAdminCrudRouteState';
import { useFormSnapshotDirty } from '@/shared/composables/useFormSnapshotDirty';
import { useUnsavedChangesGuard } from '@/shared/composables/useUnsavedChangesGuard';
import AdminCompactFilters from '@/shared/ui/AdminCompactFilters.vue';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminStickyActions from '@/shared/ui/AdminStickyActions.vue';
import AdminSummaryList from '@/shared/ui/AdminSummaryList.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const ticketManager = reactive(useBranchTicketManager());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.tickets.list,
  detailRouteName: adminCrudRouteNames.tickets.detail,
  editRouteName: adminCrudRouteNames.tickets.edit,
  idParam: adminCrudRouteNames.tickets.idParam,
});

const searchQuery = ref('');

const editDirty = useFormSnapshotDirty(() => {
  return {
    items: ticketManager.form.items.map((item) => ({
      ...item,
      badgeLabels: [...item.badgeLabels],
    })),
    notes: ticketManager.form.notes.map((note) => ({ ...note })),
  };
});

const { confirmLeave } = useUnsavedChangesGuard(() => {
  return routeMode.value === 'edit' && editDirty.isDirty.value;
});

const routeMode = computed(() => routeState.mode.value);

const showInlineDetail = computed(() => {
  return routeState.isDesktop.value && routeMode.value === 'detail' && Boolean(selectedBranch.value);
});

const isRoutePanelOpen = computed(() => {
  return routeState.showDetailRoutePanel.value || routeMode.value === 'edit';
});

const routePanelTitle = computed(() => {
  if (routeMode.value === 'edit') {
    return selectedBranch.value?.name || 'Редактировать билеты';
  }

  return selectedBranch.value?.name || 'Карточка филиала';
});

const routePanelEyebrow = computed(() => {
  return routeMode.value === 'detail' ? 'Карточка билетов' : 'Редактирование';
});

const routePanelVariant = computed<'detail' | 'form'>(() => {
  return routeMode.value === 'detail' ? 'detail' : 'form';
});

const routePanelCloseLabel = computed(() => {
  return routeMode.value === 'detail' ? 'К списку' : 'Закрыть';
});

const filteredBranches = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) {
    return ticketManager.branchOptions;
  }

  return ticketManager.branchOptions.filter((branch) => {
    return `${branch.name} ${branch.city} ${branch.shortLabel}`.toLowerCase().includes(query);
  });
});

const selectedBranch = computed(() => {
  return ticketManager.branchOptions.find((branch) => {
    return branch.id === ticketManager.selectedBranchId;
  }) ?? null;
});

const sortedItems = computed<AdminBranchTicketItem[]>(() => {
  return [...ticketManager.form.items].sort((left, right) => {
    if (left.displayOrder !== right.displayOrder) {
      return left.displayOrder - right.displayOrder;
    }
    return left.title.localeCompare(right.title);
  });
});

const sortedNotes = computed<AdminBranchTicketNote[]>(() => {
  return [...ticketManager.form.notes].sort((left, right) => {
    if (left.displayOrder !== right.displayOrder) {
      return left.displayOrder - right.displayOrder;
    }
    return left.text.localeCompare(right.text);
  });
});

const ticketSummaryItems = computed(() => {
  return [
    { label: 'Типов билетов', value: String(ticketManager.form.items.length) },
    {
      label: 'Активных билетов',
      value: String(ticketManager.form.items.filter((item) => item.isActive).length),
    },
    {
      label: 'Активных подсказок',
      value: String(ticketManager.form.notes.filter((item) => item.isActive).length),
    },
  ];
});

const itemSummaryItems = computed(() => {
  return [
    {
      label: 'С пометками',
      value: String(ticketManager.form.items.filter((item) => item.badgeLabels.length > 0).length),
    },
  ];
});

const noteSummaryItems = computed(() => {
  return [{ label: 'Всего подсказок', value: String(ticketManager.form.notes.length) }];
});

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, branchId]) => {
    if ((mode === 'detail' || mode === 'edit') && branchId) {
      if (ticketManager.selectedBranchId !== branchId) {
        await ticketManager.selectBranch(branchId);
      }
      await nextTick();
      editDirty.markClean();
    }
  },
  { immediate: true },
);

onMounted(() => {
  void ticketManager.initialize();
});

async function handlePanelClose() {
  if (routeMode.value === 'edit' && !confirmLeave()) {
    return;
  }

  if (routeMode.value === 'detail') {
    await routeState.closeDetail();
    return;
  }

  await routeState.closeEditor();
}

async function handleSave() {
  await ticketManager.save();

  if (!ticketManager.contentErrorMessage) {
    editDirty.markClean();
    await routeState.goToDetail(ticketManager.selectedBranchId);
  }
}

function formatPrice(priceTenge: number) {
  return `${priceTenge} тг`;
}

function joinBadgeLabels(badgeLabels: string[]) {
  return badgeLabels.join('\n');
}

function updateBadgeLabels(index: number, rawValue: string) {
  ticketManager.form.items[index].badgeLabels = rawValue
    .split('\n')
    .map((label) => label.trim())
    .filter(Boolean);
}
</script>

<style scoped>
.tickets-detail-view {
  display: grid;
  gap: 12px;
}

.tickets-detail-view__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.tickets-detail-view__list {
  display: grid;
  gap: 8px;
  margin: 0;
  padding-left: 18px;
}
</style>
