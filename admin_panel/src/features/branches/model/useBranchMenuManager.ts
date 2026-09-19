import { reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import {
  getAdminBranchMenu,
  listAdminBranches,
  upsertAdminBranchMenu,
} from '@/features/branches/api/adminBranchesApi';
import type {
  AdminBranchMenu,
  AdminBranchMenuCategory,
  AdminBranchMenuItem,
  AdminBranchMenuPayload,
  AdminBranchSummary,
} from '@/features/branches/model/adminBranch';

const defaultCategory = (index = 0): AdminBranchMenuCategory => ({
  key: createCategoryKey(index),
  title: '',
  displayOrder: index,
  isActive: true,
});

const defaultItem = (categoryKey: string, index = 0): AdminBranchMenuItem => ({
  title: '',
  priceTenge: 0,
  imageUrl: '',
  categoryKey,
  displayOrder: index,
  isActive: true,
});

const defaultForm = (): AdminBranchMenuPayload => {
  const category = defaultCategory(1);
  return {
    categories: [category],
    items: [defaultItem(category.key, 1)],
  };
};

export function useBranchMenuManager() {
  const branchOptions = ref<AdminBranchSummary[]>([]);
  const selectedBranchId = ref('');
  const isBranchesLoading = ref(false);
  const isContentLoading = ref(false);
  const isSaving = ref(false);
  const branchesErrorMessage = ref('');
  const contentErrorMessage = ref('');
  const successMessage = ref('');

  const form = reactive<AdminBranchMenuPayload>(defaultForm());

  async function initialize() {
    await loadBranchOptions();
  }

  async function loadBranchOptions() {
    isBranchesLoading.value = true;
    branchesErrorMessage.value = '';

    try {
      branchOptions.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminBranches({ accessToken, includeInactive: true });
      });

      const fallbackBranchId = selectedBranchId.value || branchOptions.value[0]?.id || '';
      if (fallbackBranchId) {
        await selectBranch(fallbackBranchId);
      }
    } catch (error) {
      branchesErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить филиалы для раздела меню.',
      );
    } finally {
      isBranchesLoading.value = false;
    }
  }

  async function selectBranch(branchId: string) {
    if (!branchId) {
      return;
    }

    selectedBranchId.value = branchId;
    successMessage.value = '';
    contentErrorMessage.value = '';
    isContentLoading.value = true;

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return getAdminBranchMenu({ accessToken, branchId });
      });

      applyForm(response);
    } catch (error) {
      contentErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось открыть меню филиала.',
      );
    } finally {
      isContentLoading.value = false;
    }
  }

  async function save() {
    if (!selectedBranchId.value) {
      return;
    }

    isSaving.value = true;
    contentErrorMessage.value = '';
    successMessage.value = '';

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return upsertAdminBranchMenu({
          accessToken,
          branchId: selectedBranchId.value,
          payload: form,
        });
      });

      applyForm(response);
      successMessage.value = 'Меню сохранено.';
    } catch (error) {
      contentErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить меню.',
      );
    } finally {
      isSaving.value = false;
    }
  }

  function addCategory() {
    const nextIndex = form.categories.length + 1;
    form.categories.push(defaultCategory(nextIndex));
  }

  function removeCategory(index: number) {
    const removed = form.categories[index];
    form.categories.splice(index, 1);

    if (form.categories.length === 0) {
      const fallbackCategory = defaultCategory(1);
      form.categories.push(fallbackCategory);
      reassignItemsToCategory(removed?.key, fallbackCategory.key);
      return;
    }

    if (removed != null) {
      reassignItemsToCategory(removed.key, form.categories[0].key);
    }
  }

  function addItem() {
    const fallbackCategoryKey = form.categories[0]?.key ?? createCategoryKey(1);
    const nextIndex = form.items.length + 1;
    form.items.push(defaultItem(fallbackCategoryKey, nextIndex));
  }

  function removeItem(index: number) {
    form.items.splice(index, 1);
    if (form.items.length === 0) {
      addItem();
    }
  }

  function applyForm(response: AdminBranchMenu) {
    Object.assign(form, {
      categories: response.categories.map((category) => ({ ...category })),
      items: response.items.map((item) => ({ ...item })),
    });

    if (form.categories.length === 0) {
      form.categories.push(defaultCategory(1));
    }
    if (form.items.length === 0) {
      form.items.push(defaultItem(form.categories[0].key, 1));
    }
  }

  function reassignItemsToCategory(
    removedCategoryKey: string | undefined,
    nextCategoryKey: string,
  ) {
    if (!removedCategoryKey) {
      return;
    }

    form.items.forEach((item) => {
      if (item.categoryKey === removedCategoryKey) {
        item.categoryKey = nextCategoryKey;
      }
    });
  }

  return {
    addCategory,
    addItem,
    branchOptions,
    branchesErrorMessage,
    contentErrorMessage,
    form,
    initialize,
    isBranchesLoading,
    isContentLoading,
    isSaving,
    removeCategory,
    removeItem,
    save,
    selectBranch,
    selectedBranchId,
    successMessage,
  };
}

function createCategoryKey(index: number) {
  return `menu-category-${index}-${Date.now()}`;
}
