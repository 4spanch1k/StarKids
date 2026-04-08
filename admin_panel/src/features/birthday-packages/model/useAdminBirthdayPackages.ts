import { computed, reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import {
  createAdminBirthdayPackage,
  getAdminBirthdayPackage,
  listAdminBirthdayPackages,
  updateAdminBirthdayPackage,
} from '@/features/birthday-packages/api/adminBirthdayPackagesApi';
import type {
  AdminBirthdayPackageCreatePayload,
  AdminBirthdayPackageDetail,
  AdminBirthdayPackageSummary,
  AdminBirthdayPackageUpdatePayload,
} from '@/features/birthday-packages/model/adminBirthdayPackage';
import { listAdminBranches } from '@/features/branches/api/adminBranchesApi';
import type { AdminBranchSummary } from '@/features/branches/model/adminBranch';

type PackageStatusFilter = 'all' | 'active' | 'inactive';

const defaultForm = (): AdminBirthdayPackageCreatePayload => ({
  branchId: '',
  slug: '',
  name: '',
  priceFrom: 0,
  priceLabel: '',
  guestCapacityLabel: '',
  description: '',
  highlights: [],
  imageUrl: '',
  isFeatured: false,
  isActive: true,
  displayOrder: 0,
});

export function useAdminBirthdayPackages() {
  const branchOptions = ref<AdminBranchSummary[]>([]);
  const packages = ref<AdminBirthdayPackageSummary[]>([]);
  const selectedPackageId = ref('');
  const selectedPackage = ref<AdminBirthdayPackageDetail | null>(null);
  const form = reactive<AdminBirthdayPackageUpdatePayload>(defaultForm());
  const createForm = reactive<AdminBirthdayPackageCreatePayload>(defaultForm());
  const searchQuery = ref('');
  const branchFilter = ref('');
  const statusFilter = ref<PackageStatusFilter>('all');
  const isCreating = ref(false);

  const isListLoading = ref(false);
  const isDetailLoading = ref(false);
  const isSaving = ref(false);
  const isCreateSaving = ref(false);
  const isBranchesLoading = ref(false);

  const branchesErrorMessage = ref('');
  const listErrorMessage = ref('');
  const detailErrorMessage = ref('');
  const saveErrorMessage = ref('');
  const saveSuccessMessage = ref('');
  const createErrorMessage = ref('');
  const createSuccessMessage = ref('');

  const filteredPackages = computed(() => {
    const query = searchQuery.value.trim().toLowerCase();

    return packages.value.filter((item) => {
      const matchesSearch =
        !query ||
        `${item.name} ${item.slug} ${item.priceLabel} ${item.guestCapacityLabel}`
          .toLowerCase()
          .includes(query);
      const matchesBranch = !branchFilter.value || item.branchId === branchFilter.value;
      const matchesStatus =
        statusFilter.value === 'all' ||
        (statusFilter.value === 'active' && item.isActive) ||
        (statusFilter.value === 'inactive' && !item.isActive);
      return matchesSearch && matchesBranch && matchesStatus;
    });
  });

  async function initialize() {
    await Promise.all([loadBranchOptions(), loadPackages()]);
  }

  async function loadBranchOptions() {
    isBranchesLoading.value = true;
    branchesErrorMessage.value = '';

    try {
      branchOptions.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminBranches({ accessToken, includeInactive: true });
      });

      if (!createForm.branchId) {
        createForm.branchId = branchOptions.value[0]?.id || '';
      }
    } catch (error) {
      branchesErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить филиалы для пакетов.',
      );
    } finally {
      isBranchesLoading.value = false;
    }
  }

  async function loadPackages() {
    isListLoading.value = true;
    listErrorMessage.value = '';

    try {
      packages.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminBirthdayPackages({ accessToken, includeInactive: true });
      });

      if (!isCreating.value) {
        const nextSelectedId =
          filteredPackages.value.find((item) => item.id === selectedPackageId.value)?.id ??
          filteredPackages.value[0]?.id ??
          '';

        if (nextSelectedId) {
          await selectPackage(nextSelectedId);
        } else {
          selectedPackageId.value = '';
          selectedPackage.value = null;
        }
      }
    } catch (error) {
      listErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить пакеты дней рождения.',
      );
    } finally {
      isListLoading.value = false;
    }
  }

  async function selectPackage(packageId: string) {
    if (!packageId) {
      return;
    }

    isCreating.value = false;
    selectedPackageId.value = packageId;
    selectedPackage.value = null;
    detailErrorMessage.value = '';
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';
    isDetailLoading.value = true;

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return getAdminBirthdayPackage({ accessToken, packageId });
      });

      selectedPackage.value = response;
      Object.assign(form, {
        branchId: response.branchId,
        slug: response.slug,
        name: response.name,
        priceFrom: response.priceFrom,
        priceLabel: response.priceLabel,
        guestCapacityLabel: response.guestCapacityLabel,
        description: response.description,
        highlights: response.highlights,
        imageUrl: response.imageUrl,
        isFeatured: response.isFeatured,
        isActive: response.isActive,
        displayOrder: response.displayOrder,
      });
    } catch (error) {
      detailErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось открыть пакет.',
      );
    } finally {
      isDetailLoading.value = false;
    }
  }

  function startCreate() {
    isCreating.value = true;
    selectedPackageId.value = '';
    selectedPackage.value = null;
    Object.assign(createForm, defaultForm(), {
      branchId: branchOptions.value[0]?.id || '',
    });
    createErrorMessage.value = '';
    createSuccessMessage.value = '';
  }

  function cancelCreate() {
    isCreating.value = false;
    Object.assign(createForm, defaultForm(), {
      branchId: branchOptions.value[0]?.id || '',
    });
    const fallbackPackageId = filteredPackages.value[0]?.id;
    if (fallbackPackageId) {
      void selectPackage(fallbackPackageId);
    }
  }

  async function saveCreate() {
    isCreateSaving.value = true;
    createErrorMessage.value = '';
    createSuccessMessage.value = '';

    try {
      const createdPackage = await executeAuthorizedAdminRequest((accessToken) => {
        return createAdminBirthdayPackage({
          accessToken,
          payload: createForm,
        });
      });

      createSuccessMessage.value = 'Пакет создан.';
      isCreating.value = false;
      await loadPackages();
      await selectPackage(createdPackage.id);
    } catch (error) {
      createErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось создать пакет.',
      );
    } finally {
      isCreateSaving.value = false;
    }
  }

  async function save() {
    if (!selectedPackageId.value) {
      return;
    }

    isSaving.value = true;
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';

    try {
      const savedPackage = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminBirthdayPackage({
          accessToken,
          packageId: selectedPackageId.value,
          payload: form,
        });
      });

      selectedPackage.value = savedPackage;
      packages.value = packages.value.map((item) => {
        if (item.id !== savedPackage.id) {
          return item;
        }

        return {
          id: savedPackage.id,
          branchId: savedPackage.branchId,
          slug: savedPackage.slug,
          name: savedPackage.name,
          priceFrom: savedPackage.priceFrom,
          priceLabel: savedPackage.priceLabel,
          guestCapacityLabel: savedPackage.guestCapacityLabel,
          imageUrl: savedPackage.imageUrl,
          isFeatured: savedPackage.isFeatured,
          isActive: savedPackage.isActive,
          displayOrder: savedPackage.displayOrder,
        };
      });
      saveSuccessMessage.value = 'Пакет сохранен.';
    } catch (error) {
      saveErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить пакет.',
      );
    } finally {
      isSaving.value = false;
    }
  }

  return {
    branchFilter,
    branchesErrorMessage,
    branchOptions,
    cancelCreate,
    createErrorMessage,
    createForm,
    createSuccessMessage,
    detailErrorMessage,
    filteredPackages,
    form,
    initialize,
    isBranchesLoading,
    isCreateSaving,
    isCreating,
    isDetailLoading,
    isListLoading,
    isSaving,
    listErrorMessage,
    loadPackages,
    packages,
    save,
    saveCreate,
    saveErrorMessage,
    saveSuccessMessage,
    searchQuery,
    selectPackage,
    selectedPackage,
    selectedPackageId,
    startCreate,
    statusFilter,
  };
}
