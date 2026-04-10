import { computed, reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import {
  createAdminBranch,
  getAdminBranch,
  getAdminBranchContacts,
  listAdminBranches,
  updateAdminBranch,
  updateAdminBranchContacts,
} from '@/features/branches/api/adminBranchesApi';
import type {
  AdminBranchContacts,
  AdminBranchContactsPayload,
  AdminBranchCreatePayload,
  AdminBranchDetail,
  AdminBranchSummary,
  AdminBranchUpdatePayload,
} from '@/features/branches/model/adminBranch';

type BranchStatusFilter = 'all' | 'active' | 'inactive';

const defaultCreateForm = (): AdminBranchCreatePayload => ({
  slug: '',
  name: '',
  city: 'Шымкент',
  address: '',
  shortLabel: '',
  workingHours: '',
  description: '',
  phone: '',
  whatsappPhone: '',
  mapUrl: '',
  routeLabel: '',
  parkingHint: '',
  arrivalHint: '',
  heroImageUrl: '',
  galleryImageUrls: [],
  facilities: [],
  displayOrder: 0,
  isActive: true,
});

const defaultBranchForm = (): AdminBranchUpdatePayload => ({
  slug: '',
  name: '',
  city: '',
  address: '',
  shortLabel: '',
  workingHours: '',
  description: '',
  phone: '',
  whatsappPhone: '',
  mapUrl: '',
  routeLabel: '',
  parkingHint: '',
  arrivalHint: '',
  heroImageUrl: '',
  galleryImageUrls: [],
  facilities: [],
  displayOrder: 0,
  isActive: true,
});

const defaultContactsForm = (): AdminBranchContactsPayload => ({
  address: '',
  phone: '',
  whatsappPhone: '',
  mapUrl: '',
  routeLabel: '',
  parkingHint: '',
  arrivalHint: '',
});

export function useAdminBranches() {
  const branches = ref<AdminBranchSummary[]>([]);
  const selectedBranchId = ref('');
  const selectedBranch = ref<AdminBranchDetail | null>(null);
  const searchQuery = ref('');
  const statusFilter = ref<BranchStatusFilter>('all');
  const isCreating = ref(false);

  const createForm = reactive<AdminBranchCreatePayload>(defaultCreateForm());
  const branchForm = reactive<AdminBranchUpdatePayload>(defaultBranchForm());
  const contactsForm = reactive<AdminBranchContactsPayload>(defaultContactsForm());

  const isListLoading = ref(false);
  const isDetailLoading = ref(false);
  const isCreateSaving = ref(false);
  const isBranchSaving = ref(false);
  const isContactsSaving = ref(false);

  const listErrorMessage = ref('');
  const detailErrorMessage = ref('');
  const createErrorMessage = ref('');
  const createSuccessMessage = ref('');
  const branchErrorMessage = ref('');
  const branchSuccessMessage = ref('');
  const contactsErrorMessage = ref('');
  const contactsSuccessMessage = ref('');

  const filteredBranches = computed(() => {
    const query = searchQuery.value.trim().toLowerCase();

    return branches.value.filter((branch) => {
      const matchesSearch =
        !query ||
        `${branch.name} ${branch.city} ${branch.shortLabel}`.toLowerCase().includes(query);

      const matchesStatus =
        statusFilter.value === 'all' ||
        (statusFilter.value === 'active' && branch.isActive) ||
        (statusFilter.value === 'inactive' && !branch.isActive);

      return matchesSearch && matchesStatus;
    });
  });

  async function initialize() {
    await loadBranches();
  }

  async function loadBranches() {
    isListLoading.value = true;
    listErrorMessage.value = '';

    try {
      branches.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminBranches({ accessToken, includeInactive: true });
      });

      if (!isCreating.value) {
        const nextSelectedId =
          filteredBranches.value.find((branch) => branch.id === selectedBranchId.value)?.id ??
          filteredBranches.value[0]?.id ??
          '';

        if (nextSelectedId) {
          await selectBranch(nextSelectedId);
        } else {
          selectedBranchId.value = '';
          selectedBranch.value = null;
        }
      }
    } catch (error) {
      listErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить список филиалов.',
      );
    } finally {
      isListLoading.value = false;
    }
  }

  async function selectBranch(branchId: string) {
    if (!branchId) {
      return;
    }

    isCreating.value = false;
    selectedBranchId.value = branchId;
    selectedBranch.value = null;
    detailErrorMessage.value = '';
    branchErrorMessage.value = '';
    branchSuccessMessage.value = '';
    contactsErrorMessage.value = '';
    contactsSuccessMessage.value = '';

    isDetailLoading.value = true;

    try {
      const [branch, contacts] = await Promise.all([
        executeAuthorizedAdminRequest((accessToken) => {
          return getAdminBranch({ accessToken, branchId });
        }),
        executeAuthorizedAdminRequest((accessToken) => {
          return getAdminBranchContacts({ accessToken, branchId });
        }),
      ]);

      selectedBranch.value = branch;
      applyBranchForm(branch);
      applyContactsForm(contacts);
    } catch (error) {
      detailErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить карточку филиала.',
      );
    } finally {
      isDetailLoading.value = false;
    }
  }

  function startCreate() {
    isCreating.value = true;
    selectedBranchId.value = '';
    selectedBranch.value = null;
    detailErrorMessage.value = '';
    createErrorMessage.value = '';
    createSuccessMessage.value = '';
    Object.assign(createForm, defaultCreateForm());
  }

  function cancelCreate() {
    isCreating.value = false;
    createErrorMessage.value = '';
    createSuccessMessage.value = '';
    Object.assign(createForm, defaultCreateForm());

    const fallbackBranchId = filteredBranches.value[0]?.id;
    if (fallbackBranchId) {
      void selectBranch(fallbackBranchId);
    }
  }

  async function saveCreate() {
    isCreateSaving.value = true;
    createErrorMessage.value = '';
    createSuccessMessage.value = '';

    try {
      const createdBranch = await executeAuthorizedAdminRequest((accessToken) => {
        return createAdminBranch({
          accessToken,
          payload: createForm,
        });
      });

      createSuccessMessage.value = 'Филиал создан.';
      isCreating.value = false;
      await loadBranches();
      await selectBranch(createdBranch.id);
    } catch (error) {
      createErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось создать филиал.',
      );
      throw error;
    } finally {
      isCreateSaving.value = false;
    }
  }

  async function saveBranch() {
    if (!selectedBranchId.value) {
      return;
    }

    isBranchSaving.value = true;
    branchErrorMessage.value = '';
    branchSuccessMessage.value = '';

    try {
      const updatedBranch = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminBranch({
          accessToken,
          branchId: selectedBranchId.value,
          payload: branchForm,
        });
      });

      selectedBranch.value = updatedBranch;
      applyBranchForm(updatedBranch);
      patchBranchSummary(updatedBranch);
      branchSuccessMessage.value = 'Основные данные филиала сохранены.';
    } catch (error) {
      branchErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить филиал.',
      );
      throw error;
    } finally {
      isBranchSaving.value = false;
    }
  }

  async function saveContacts() {
    if (!selectedBranchId.value) {
      return;
    }

    isContactsSaving.value = true;
    contactsErrorMessage.value = '';
    contactsSuccessMessage.value = '';

    try {
      const savedContacts = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminBranchContacts({
          accessToken,
          branchId: selectedBranchId.value,
          payload: contactsForm,
        });
      });

      applyContactsForm(savedContacts);
      if (selectedBranch.value) {
        selectedBranch.value = {
          ...selectedBranch.value,
          address: savedContacts.address,
          phone: savedContacts.phone,
          whatsappPhone: savedContacts.whatsappPhone,
          mapUrl: savedContacts.mapUrl,
          routeLabel: savedContacts.routeLabel,
          parkingHint: savedContacts.parkingHint,
          arrivalHint: savedContacts.arrivalHint,
        };
      }
      contactsSuccessMessage.value = 'Контакты и маршрут сохранены.';
    } catch (error) {
      contactsErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить контакты филиала.',
      );
      throw error;
    } finally {
      isContactsSaving.value = false;
    }
  }

  function applyBranchForm(branch: AdminBranchDetail) {
    Object.assign(branchForm, {
      slug: branch.slug,
      name: branch.name,
      city: branch.city,
      address: branch.address,
      shortLabel: branch.shortLabel,
      workingHours: branch.workingHours,
      description: branch.description,
      phone: branch.phone,
      whatsappPhone: branch.whatsappPhone,
      mapUrl: branch.mapUrl,
      routeLabel: branch.routeLabel,
      parkingHint: branch.parkingHint,
      arrivalHint: branch.arrivalHint,
      heroImageUrl: branch.heroImageUrl,
      galleryImageUrls: branch.galleryImageUrls,
      facilities: branch.facilities,
      displayOrder: branch.displayOrder,
      isActive: branch.isActive,
    });
  }

  function applyContactsForm(contacts: AdminBranchContacts) {
    Object.assign(contactsForm, {
      address: contacts.address,
      phone: contacts.phone,
      whatsappPhone: contacts.whatsappPhone,
      mapUrl: contacts.mapUrl,
      routeLabel: contacts.routeLabel,
      parkingHint: contacts.parkingHint,
      arrivalHint: contacts.arrivalHint,
    });
  }

  function patchBranchSummary(branch: AdminBranchDetail) {
    branches.value = branches.value.map((item) => {
      if (item.id !== branch.id) {
        return item;
      }

      return {
        id: branch.id,
        slug: branch.slug,
        name: branch.name,
        city: branch.city,
        shortLabel: branch.shortLabel,
        workingHours: branch.workingHours,
        displayOrder: branch.displayOrder,
        isActive: branch.isActive,
      };
    });
  }

  return {
    branchErrorMessage,
    branchForm,
    branchSuccessMessage,
    branches,
    cancelCreate,
    contactsErrorMessage,
    contactsForm,
    contactsSuccessMessage,
    createErrorMessage,
    createForm,
    createSuccessMessage,
    detailErrorMessage,
    filteredBranches,
    initialize,
    isBranchSaving,
    isContactsSaving,
    isCreateSaving,
    isCreating,
    isDetailLoading,
    isListLoading,
    listErrorMessage,
    loadBranches,
    saveBranch,
    saveContacts,
    saveCreate,
    searchQuery,
    selectBranch,
    selectedBranch,
    selectedBranchId,
    startCreate,
    statusFilter,
  };
}
