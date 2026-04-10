<template>
  <AdminCrudWorkspace
    eyebrow="Контент филиалов"
    title="Филиалы"
    description="Филиалы, контакты и базовые параметры."
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
        class="admin-button admin-button--primary"
        @click="void routeState.goToCreate()"
      >
        Добавить филиал
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Филиалы</h2>
      </div>

      <AdminCompactFilters>
        <template #primary>
          <AdminSearchField
            v-model="branchesManager.searchQuery"
            placeholder="Найти филиал"
          />
        </template>

        <template #secondary>
          <AppSelectField
            v-model="branchesManager.statusFilter"
            label="Статус"
            :options="statusOptions"
          />
        </template>
      </AdminCompactFilters>

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

      <div v-else class="admin-list-records">
        <button
          v-for="branch in branchesManager.filteredBranches"
          :key="branch.id"
          type="button"
          class="admin-list-record"
          :class="{ 'admin-list-record--active': branch.id === branchesManager.selectedBranchId }"
          @click="void routeState.goToDetail(branch.id)"
        >
          <span class="admin-list-record__accent" aria-hidden="true"></span>
          <div class="admin-list-record__copy">
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
        v-if="branchesManager.isDetailLoading && routeMode !== 'create'"
        title="Открываем филиал"
        description="Загружаем карточку и контакты выбранной точки."
      />

      <StatePanel
        v-else-if="branchesManager.detailErrorMessage && routeMode !== 'create'"
        title="Не удалось открыть филиал"
        :description="branchesManager.detailErrorMessage"
        tone="error"
      />

      <template v-else-if="routeMode === 'create'">
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
              @click="void handlePanelClose()"
            >
              Отменить
            </button>
          </AdminStickyActions>
        </form>
      </template>

      <template v-else-if="branchesManager.selectedBranch">
        <template v-if="routeMode === 'detail'">
          <div class="branches-detail-view">
            <header class="admin-detail-header">
              <div class="admin-detail-header__copy">
                <p class="admin-detail-header__eyebrow">
                  Код: {{ branchesManager.selectedBranch.id }}
                </p>
                <div class="admin-detail-header__title-row">
                  <h2>{{ branchesManager.selectedBranch.name }}</h2>
                  <StatusBadge
                    :label="branchesManager.selectedBranch.isActive ? 'Активен' : 'Неактивен'"
                    :tone="branchesManager.selectedBranch.isActive ? 'closed' : 'neutral'"
                  />
                </div>
                <p class="admin-detail-header__summary">
                  {{ branchesManager.selectedBranch.city }} · {{ branchesManager.selectedBranch.shortLabel }}
                </p>
              </div>

              <div class="branches-detail-view__actions">
                <button
                  type="button"
                  class="admin-button admin-button--primary"
                  @click="void routeState.goToEdit(branchesManager.selectedBranch.id)"
                >
                  Редактировать
                </button>
              </div>
            </header>

            <AdminSummaryList
              title="Основные данные"
              :items="branchSummaryItems"
            />

            <AdminSummaryList
              title="Контакты и маршрут"
              :items="contactsSummaryItems"
            />

            <AdminSummaryList
              v-if="branchFacilitiesItems.length"
              title="Удобства"
              description="Ключевые удобства, которые видит пользователь."
            >
              <ul class="branches-detail-view__list">
                <li
                  v-for="facility in branchFacilitiesItems"
                  :key="facility"
                >
                  {{ facility }}
                </li>
              </ul>
            </AdminSummaryList>
          </div>
        </template>

        <template v-else>
          <form
            ref="branchFormRef"
            class="admin-form-stack"
            novalidate
            @submit.prevent="handleBranchSave"
          >
            <div class="admin-section-heading">
              <h2>Редактировать филиал</h2>
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
              v-if="editSummaryMessage"
              :message="editSummaryMessage"
              :errors="combinedEditErrors"
            />
            <p
              v-if="branchesManager.branchSuccessMessage || branchesManager.contactsSuccessMessage"
              class="admin-inline-message admin-inline-message--success"
            >
              {{ branchesManager.branchSuccessMessage || branchesManager.contactsSuccessMessage }}
            </p>

            <AdminStickyActions>
              <button
                type="submit"
                class="admin-button admin-button--primary"
                :disabled="branchesManager.isBranchSaving || branchesManager.isContactsSaving"
              >
                {{
                  branchesManager.isBranchSaving || branchesManager.isContactsSaving
                    ? 'Сохраняем…'
                    : 'Сохранить изменения'
                }}
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
      </template>

      <StatePanel
        v-else
        title="Выберите филиал"
        description="Откройте карточку филиала, чтобы посмотреть или изменить данные."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';

import { adminCrudRouteNames } from '@/app/router/adminCrudRoutes';
import { useAdminBranches } from '@/features/branches/model/useAdminBranches';
import type { AdminFieldErrors } from '@/shared/lib/adminApiErrors';
import {
  resolveAdminApiErrorMessage,
  resolveAdminApiFieldErrors,
} from '@/shared/lib/adminApiErrors';
import { useAdminCrudRouteState } from '@/shared/composables/useAdminCrudRouteState';
import { useFormSnapshotDirty } from '@/shared/composables/useFormSnapshotDirty';
import { useUnsavedChangesGuard } from '@/shared/composables/useUnsavedChangesGuard';
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
import AdminCompactFilters from '@/shared/ui/AdminCompactFilters.vue';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminFormErrorBanner from '@/shared/ui/AdminFormErrorBanner.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminStickyActions from '@/shared/ui/AdminStickyActions.vue';
import AdminSummaryList from '@/shared/ui/AdminSummaryList.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import AppSelectField from '@/shared/ui/AppSelectField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const branchesManager = reactive(useAdminBranches());
const routeState = useAdminCrudRouteState({
  listRouteName: adminCrudRouteNames.branches.list,
  detailRouteName: adminCrudRouteNames.branches.detail,
  createRouteName: adminCrudRouteNames.branches.create,
  editRouteName: adminCrudRouteNames.branches.edit,
  idParam: adminCrudRouteNames.branches.idParam,
});

const createFormRef = ref<HTMLFormElement | null>(null);
const branchFormRef = ref<HTMLFormElement | null>(null);
const createSummaryMessage = ref('');
const editSummaryMessage = ref('');
const createFieldErrors = reactive<AdminFieldErrors>({});
const branchFieldErrors = reactive<AdminFieldErrors>({});
const contactsFieldErrors = reactive<AdminFieldErrors>({});

const createDirty = useFormSnapshotDirty(() => ({ ...branchesManager.createForm }));
const editDirty = useFormSnapshotDirty(() => ({
  branch: { ...branchesManager.branchForm },
  contacts: { ...branchesManager.contactsForm },
}));

const { confirmLeave } = useUnsavedChangesGuard(() => {
  if (routeMode.value === 'create') {
    return createDirty.isDirty.value;
  }

  if (routeMode.value === 'edit') {
    return editDirty.isDirty.value;
  }

  return false;
});

const statusOptions = [
  { label: 'Все статусы', value: 'all' },
  { label: 'Активные', value: 'active' },
  { label: 'Неактивные', value: 'inactive' },
];

const routeMode = computed(() => routeState.mode.value);

const showInlineDetail = computed(() => {
  return routeState.isDesktop.value && routeMode.value === 'detail' && Boolean(branchesManager.selectedBranch);
});

const isRoutePanelOpen = computed(() => {
  return routeState.showDetailRoutePanel.value || routeMode.value === 'create' || routeMode.value === 'edit';
});

const routePanelTitle = computed(() => {
  if (routeMode.value === 'create') {
    return 'Создать филиал';
  }

  if (routeMode.value === 'edit') {
    return branchesManager.selectedBranch?.name || 'Редактировать филиал';
  }

  return branchesManager.selectedBranch?.name || 'Карточка филиала';
});

const routePanelEyebrow = computed(() => {
  return routeMode.value === 'detail' ? 'Карточка филиала' : 'Редактирование';
});

const routePanelVariant = computed<'detail' | 'form'>(() => {
  return routeMode.value === 'detail' ? 'detail' : 'form';
});

const routePanelCloseLabel = computed(() => {
  return routeMode.value === 'detail' ? 'К списку' : 'Закрыть';
});

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

const branchSummaryItems = computed(() => {
  const branch = branchesManager.selectedBranch;
  if (!branch) {
    return [];
  }

  return [
    { label: 'Служебный код', value: branch.slug },
    { label: 'Короткая подпись', value: branch.shortLabel },
    { label: 'Город', value: branch.city },
    { label: 'Режим работы', value: branch.workingHours },
    { label: 'Адрес', value: branch.address, fullWidth: true },
    { label: 'Описание', value: branch.description, fullWidth: true },
  ];
});

const contactsSummaryItems = computed(() => {
  const branch = branchesManager.selectedBranch;
  const contacts = branchesManager.contactsForm;
  if (!branch) {
    return [];
  }

  return [
    { label: 'Телефон', value: contacts.phone || branch.phone },
    { label: 'WhatsApp', value: contacts.whatsappPhone || branch.whatsappPhone },
    { label: 'Маршрут', value: contacts.routeLabel, fullWidth: true },
    { label: 'Ссылка на карту', value: contacts.mapUrl, fullWidth: true },
    { label: 'Подсказка по парковке', value: contacts.parkingHint, fullWidth: true },
    { label: 'Подсказка по входу', value: contacts.arrivalHint, fullWidth: true },
  ];
});

const branchFacilitiesItems = computed(() => {
  return branchesManager.selectedBranch?.facilities ?? [];
});

const combinedEditErrors = computed(() => {
  return {
    ...branchFieldErrors,
    ...contactsFieldErrors,
  };
});

watch(
  () => [routeMode.value, routeState.activeId.value] as const,
  async ([mode, branchId]) => {
    if (mode === 'create') {
      clearBranchFormFeedback();
      branchesManager.startCreate();
      await nextTick();
      createDirty.markClean();
      return;
    }

    if ((mode === 'detail' || mode === 'edit') && branchId) {
      if (branchesManager.selectedBranchId !== branchId || !branchesManager.selectedBranch) {
        await branchesManager.selectBranch(branchId);
      }
      await nextTick();
      editDirty.markClean();
    }
  },
  { immediate: true },
);

onMounted(() => {
  void branchesManager.initialize();
});

async function handlePanelClose() {
  if ((routeMode.value === 'create' || routeMode.value === 'edit') && !confirmLeave()) {
    return;
  }

  clearBranchFormFeedback();

  if (routeMode.value === 'detail') {
    await routeState.closeDetail();
    return;
  }

  if (routeMode.value === 'create' && branchesManager.isCreating) {
    branchesManager.cancelCreate();
  }

  await routeState.closeEditor();
}

async function handleCreateSubmit() {
  const errors = compactErrors({
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
  });

  replaceFieldErrors(createFieldErrors, errors);
  createSummaryMessage.value = Object.keys(errors).length ? 'Проверьте обязательные поля.' : '';

  if (Object.keys(errors).length > 0) {
    await focusFirstFieldError(createFormRef.value, createFieldErrors);
    return;
  }

  try {
    createSummaryMessage.value = '';
    await branchesManager.saveCreate();
    createDirty.markClean();

    if (branchesManager.selectedBranchId) {
      await routeState.goToDetail(branchesManager.selectedBranchId);
    }
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
  const branchErrors = compactErrors({
    slug: validateRequiredText(
      branchesManager.branchForm.slug || '',
      'Введите служебный код филиала.',
      2,
    ),
    shortLabel: validateRequiredText(
      branchesManager.branchForm.shortLabel || '',
      'Введите короткую подпись.',
      2,
    ),
    name: validateRequiredText(
      branchesManager.branchForm.name || '',
      'Введите название филиала.',
      2,
    ),
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
  });

  const contactErrors = compactErrors({
    address: validateRequiredText(
      branchesManager.contactsForm.address,
      'Введите адрес филиала.',
      4,
    ),
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
  });

  replaceFieldErrors(branchFieldErrors, branchErrors);
  replaceFieldErrors(contactsFieldErrors, contactErrors);
  editSummaryMessage.value =
    Object.keys(branchErrors).length || Object.keys(contactErrors).length
      ? 'Проверьте обязательные поля.'
      : '';

  if (editSummaryMessage.value) {
    await focusFirstFieldError(branchFormRef.value, combinedEditErrors.value);
    return;
  }

  try {
    editSummaryMessage.value = '';
    await branchesManager.saveBranch();
    await branchesManager.saveContacts();
    editDirty.markClean();
    await routeState.goToDetail(branchesManager.selectedBranchId);
  } catch (error) {
    const fieldErrors = resolveAdminApiFieldErrors(error);
    replaceFieldErrors(branchFieldErrors, {
      ...branchFieldErrors,
      ...fieldErrors,
    });
    replaceFieldErrors(contactsFieldErrors, {
      ...contactsFieldErrors,
      ...fieldErrors,
    });
    editSummaryMessage.value = resolveAdminApiErrorMessage(
      error,
      'Не удалось сохранить филиал.',
    );
    await focusFirstFieldError(branchFormRef.value, {
      ...branchFieldErrors,
      ...contactsFieldErrors,
    });
  }
}

function clearCreateFieldError(field: string) {
  clearFieldError(createFieldErrors, field);
  createSummaryMessage.value = '';
}

function clearBranchFieldError(field: string) {
  clearFieldError(branchFieldErrors, field);
  editSummaryMessage.value = '';
}

function clearContactsFieldError(field: string) {
  clearFieldError(contactsFieldErrors, field);
  editSummaryMessage.value = '';
}

function clearBranchFormFeedback() {
  replaceFieldErrors(createFieldErrors, {});
  replaceFieldErrors(branchFieldErrors, {});
  replaceFieldErrors(contactsFieldErrors, {});
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
.branches-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.branches-form-grid__full {
  grid-column: 1 / -1;
}

.branches-detail-view {
  display: grid;
  gap: 12px;
}

.branches-detail-view__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.branches-detail-view__list {
  display: grid;
  gap: 8px;
  margin: 0;
  padding-left: 18px;
}

@media (max-width: 900px) {
  .branches-form-grid {
    grid-template-columns: 1fr;
  }
}
</style>
