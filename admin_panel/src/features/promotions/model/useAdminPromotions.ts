import { computed, reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import { listAdminBranches } from '@/features/branches/api/adminBranchesApi';
import type { AdminBranchSummary } from '@/features/branches/model/adminBranch';
import {
  createAdminPromotion,
  getAdminPromotion,
  listAdminPromotions,
  updateAdminPromotion,
} from '@/features/promotions/api/adminPromotionsApi';
import type {
  AdminPromotion,
  AdminPromotionCreatePayload,
  AdminPromotionUpdatePayload,
} from '@/features/promotions/model/adminPromotion';

type PublicationFilter = 'all' | 'published' | 'draft';
type ActiveFilter = 'all' | 'active' | 'inactive';

const defaultForm = (): AdminPromotionCreatePayload => ({
  title: '',
  description: '',
  badgeLabel: '',
  imageUrl: '',
  branchIds: [],
  ctaLabel: '',
  displayOrder: 0,
  isActive: true,
  isPublished: false,
});

export function useAdminPromotions() {
  const branchOptions = ref<AdminBranchSummary[]>([]);
  const promotions = ref<AdminPromotion[]>([]);
  const selectedPromotionId = ref('');
  const selectedPromotion = ref<AdminPromotion | null>(null);
  const form = reactive<AdminPromotionUpdatePayload>(defaultForm());
  const createForm = reactive<AdminPromotionCreatePayload>(defaultForm());
  const searchQuery = ref('');
  const branchFilter = ref('');
  const activeFilter = ref<ActiveFilter>('all');
  const publicationFilter = ref<PublicationFilter>('all');
  const isCreating = ref(false);

  const isBranchesLoading = ref(false);
  const isListLoading = ref(false);
  const isDetailLoading = ref(false);
  const isSaving = ref(false);
  const isCreateSaving = ref(false);

  const branchesErrorMessage = ref('');
  const listErrorMessage = ref('');
  const detailErrorMessage = ref('');
  const saveErrorMessage = ref('');
  const saveSuccessMessage = ref('');
  const createErrorMessage = ref('');
  const createSuccessMessage = ref('');

  const filteredPromotions = computed(() => {
    const query = searchQuery.value.trim().toLowerCase();

    return promotions.value.filter((promotion) => {
      const matchesSearch =
        !query ||
        `${promotion.title} ${promotion.badgeLabel} ${promotion.description}`
          .toLowerCase()
          .includes(query);
      const matchesBranch =
        !branchFilter.value || promotion.branchIds.includes(branchFilter.value);
      const matchesActive =
        activeFilter.value === 'all' ||
        (activeFilter.value === 'active' && promotion.isActive) ||
        (activeFilter.value === 'inactive' && !promotion.isActive);
      const matchesPublication =
        publicationFilter.value === 'all' ||
        (publicationFilter.value === 'published' && promotion.isPublished) ||
        (publicationFilter.value === 'draft' && !promotion.isPublished);

      return matchesSearch && matchesBranch && matchesActive && matchesPublication;
    });
  });

  async function initialize() {
    await Promise.all([loadBranchOptions(), loadPromotions()]);
  }

  async function loadBranchOptions() {
    isBranchesLoading.value = true;
    branchesErrorMessage.value = '';

    try {
      branchOptions.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminBranches({ accessToken, includeInactive: true });
      });
    } catch (error) {
      branchesErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить филиалы для акций.',
      );
    } finally {
      isBranchesLoading.value = false;
    }
  }

  async function loadPromotions() {
    isListLoading.value = true;
    listErrorMessage.value = '';

    try {
      promotions.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminPromotions({ accessToken });
      });

      if (!isCreating.value) {
        const nextSelectedId =
          filteredPromotions.value.find((item) => item.id === selectedPromotionId.value)?.id ??
          filteredPromotions.value[0]?.id ??
          '';

        if (nextSelectedId) {
          await selectPromotion(nextSelectedId);
        } else {
          selectedPromotionId.value = '';
          selectedPromotion.value = null;
        }
      }
    } catch (error) {
      listErrorMessage.value = resolveAdminRequestError(error, 'Не удалось загрузить акции.');
    } finally {
      isListLoading.value = false;
    }
  }

  async function selectPromotion(promotionId: string) {
    if (!promotionId) {
      return;
    }

    isCreating.value = false;
    selectedPromotionId.value = promotionId;
    detailErrorMessage.value = '';
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';
    isDetailLoading.value = true;

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return getAdminPromotion({ accessToken, promotionId });
      });

      selectedPromotion.value = response;
      Object.assign(form, response);
    } catch (error) {
      detailErrorMessage.value = resolveAdminRequestError(error, 'Не удалось открыть акцию.');
    } finally {
      isDetailLoading.value = false;
    }
  }

  function startCreate() {
    isCreating.value = true;
    selectedPromotionId.value = '';
    selectedPromotion.value = null;
    Object.assign(createForm, defaultForm());
    createErrorMessage.value = '';
    createSuccessMessage.value = '';
  }

  function cancelCreate() {
    isCreating.value = false;
    Object.assign(createForm, defaultForm());
    const fallbackPromotionId = filteredPromotions.value[0]?.id;
    if (fallbackPromotionId) {
      void selectPromotion(fallbackPromotionId);
    }
  }

  async function saveCreate() {
    isCreateSaving.value = true;
    createErrorMessage.value = '';
    createSuccessMessage.value = '';

    try {
      const createdPromotion = await executeAuthorizedAdminRequest((accessToken) => {
        return createAdminPromotion({
          accessToken,
          payload: createForm,
        });
      });

      createSuccessMessage.value = 'Акция создана.';
      isCreating.value = false;
      await loadPromotions();
      await selectPromotion(createdPromotion.id);
    } catch (error) {
      createErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось создать акцию.',
      );
      throw error;
    } finally {
      isCreateSaving.value = false;
    }
  }

  async function save() {
    if (!selectedPromotionId.value) {
      return;
    }

    isSaving.value = true;
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';

    try {
      const savedPromotion = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminPromotion({
          accessToken,
          promotionId: selectedPromotionId.value,
          payload: form,
        });
      });

      selectedPromotion.value = savedPromotion;
      promotions.value = promotions.value.map((item) => {
        return item.id === savedPromotion.id ? savedPromotion : item;
      });
      saveSuccessMessage.value = 'Акция сохранена.';
    } catch (error) {
      saveErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить акцию.',
      );
      throw error;
    } finally {
      isSaving.value = false;
    }
  }

  return {
    activeFilter,
    branchFilter,
    branchesErrorMessage,
    branchOptions,
    cancelCreate,
    createErrorMessage,
    createForm,
    createSuccessMessage,
    detailErrorMessage,
    filteredPromotions,
    form,
    initialize,
    isBranchesLoading,
    isCreateSaving,
    isCreating,
    isDetailLoading,
    isListLoading,
    isSaving,
    listErrorMessage,
    loadPromotions,
    promotions,
    publicationFilter,
    save,
    saveCreate,
    saveErrorMessage,
    saveSuccessMessage,
    searchQuery,
    selectPromotion,
    selectedPromotion,
    selectedPromotionId,
    startCreate,
  };
}
