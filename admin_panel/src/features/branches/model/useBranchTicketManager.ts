import { reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import {
  getAdminBranchTickets,
  listAdminBranches,
  upsertAdminBranchTickets,
} from '@/features/branches/api/adminBranchesApi';
import type {
  AdminBranchSummary,
  AdminBranchTicketItem,
  AdminBranchTicketNote,
  AdminBranchTickets,
  AdminBranchTicketsPayload,
} from '@/features/branches/model/adminBranch';

const defaultItem = (index = 1): AdminBranchTicketItem => ({
  title: '',
  description: '',
  priceTenge: 0,
  badgeLabels: [],
  displayOrder: index,
  isActive: true,
});

const defaultNote = (index = 1): AdminBranchTicketNote => ({
  text: '',
  displayOrder: index,
  isActive: true,
});

const defaultForm = (): AdminBranchTicketsPayload => ({
  items: [defaultItem(1)],
  notes: [defaultNote(1)],
});

export function useBranchTicketManager() {
  const branchOptions = ref<AdminBranchSummary[]>([]);
  const selectedBranchId = ref('');
  const isBranchesLoading = ref(false);
  const isContentLoading = ref(false);
  const isSaving = ref(false);
  const branchesErrorMessage = ref('');
  const contentErrorMessage = ref('');
  const successMessage = ref('');

  const form = reactive<AdminBranchTicketsPayload>(defaultForm());

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
        'Не удалось загрузить филиалы для раздела билетов.',
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
        return getAdminBranchTickets({ accessToken, branchId });
      });
      applyForm(response);
    } catch (error) {
      contentErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось открыть билеты филиала.',
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
        return upsertAdminBranchTickets({
          accessToken,
          branchId: selectedBranchId.value,
          payload: form,
        });
      });

      applyForm(response);
      successMessage.value = 'Билеты сохранены.';
    } catch (error) {
      contentErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить билеты.',
      );
    } finally {
      isSaving.value = false;
    }
  }

  function addItem() {
    form.items.push(defaultItem(form.items.length + 1));
  }

  function removeItem(index: number) {
    form.items.splice(index, 1);
    if (form.items.length === 0) {
      form.items.push(defaultItem(1));
    }
  }

  function addNote() {
    form.notes.push(defaultNote(form.notes.length + 1));
  }

  function removeNote(index: number) {
    form.notes.splice(index, 1);
    if (form.notes.length === 0) {
      form.notes.push(defaultNote(1));
    }
  }

  function applyForm(response: AdminBranchTickets) {
    Object.assign(form, {
      items: response.items.map((item) => ({ ...item })),
      notes: response.notes.map((note) => ({ ...note })),
    });

    if (form.items.length === 0) {
      form.items.push(defaultItem(1));
    }
    if (form.notes.length === 0) {
      form.notes.push(defaultNote(1));
    }
  }

  return {
    addItem,
    addNote,
    branchOptions,
    branchesErrorMessage,
    contentErrorMessage,
    form,
    initialize,
    isBranchesLoading,
    isContentLoading,
    isSaving,
    removeItem,
    removeNote,
    save,
    selectBranch,
    selectedBranchId,
    successMessage,
  };
}
