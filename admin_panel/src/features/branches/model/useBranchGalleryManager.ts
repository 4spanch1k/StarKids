import { reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import {
  getAdminBranchGallery,
  listAdminBranches,
  updateAdminBranchGallery,
} from '@/features/branches/api/adminBranchesApi';
import type {
  AdminBranchGallery,
  AdminBranchGalleryPayload,
  AdminBranchSummary,
} from '@/features/branches/model/adminBranch';

const defaultForm = (): AdminBranchGalleryPayload => ({
  heroImageUrl: '',
  galleryImageUrls: [],
});

export function useBranchGalleryManager() {
  const branchOptions = ref<AdminBranchSummary[]>([]);
  const selectedBranchId = ref('');
  const form = reactive<AdminBranchGalleryPayload>(defaultForm());

  const isBranchesLoading = ref(false);
  const isGalleryLoading = ref(false);
  const isSaving = ref(false);
  const branchesErrorMessage = ref('');
  const galleryErrorMessage = ref('');
  const successMessage = ref('');

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
        'Не удалось загрузить филиалы для галереи.',
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
    galleryErrorMessage.value = '';
    successMessage.value = '';
    isGalleryLoading.value = true;

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return getAdminBranchGallery({ accessToken, branchId });
      });

      applyForm(response);
    } catch (error) {
      galleryErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось открыть медиаданные филиала.',
      );
    } finally {
      isGalleryLoading.value = false;
    }
  }

  async function save() {
    if (!selectedBranchId.value) {
      return;
    }

    isSaving.value = true;
    galleryErrorMessage.value = '';
    successMessage.value = '';

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminBranchGallery({
          accessToken,
          branchId: selectedBranchId.value,
          payload: form,
        });
      });

      applyForm(response);
      successMessage.value = 'Галерея филиала сохранена.';
    } catch (error) {
      galleryErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить медиаданные филиала.',
      );
    } finally {
      isSaving.value = false;
    }
  }

  function applyForm(response: AdminBranchGallery) {
    Object.assign(form, {
      heroImageUrl: response.heroImageUrl,
      galleryImageUrls: response.galleryImageUrls,
    });
  }

  return {
    branchOptions,
    branchesErrorMessage,
    form,
    galleryErrorMessage,
    initialize,
    isBranchesLoading,
    isGalleryLoading,
    isSaving,
    save,
    selectBranch,
    selectedBranchId,
    successMessage,
  };
}
