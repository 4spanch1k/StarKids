import { computed, reactive, ref } from 'vue';

import type {
  LeadDetail,
  LeadListFilters,
  LeadListItem,
  LeadStatus,
} from '@/entities/lead/model/lead';
import { useSessionStore } from '@/features/auth/stores/useSessionStore';
import {
  fetchAdminLeadDetail,
  fetchAdminLeadList,
  fetchLeadInboxBranchOptions,
  type LeadInboxBranchFilterOption,
  updateAdminLeadStatus,
} from '@/features/leads/api/adminLeadInboxApi';
import { HttpError } from '@/shared/api/httpClient';

const defaultFilters = (): LeadListFilters => ({
  branchId: '',
  status: '',
  createdFrom: '',
  createdTo: '',
});

export function useLeadInbox() {
  const sessionStore = useSessionStore();

  const filters = reactive<LeadListFilters>(defaultFilters());
  const branchOptions = ref<LeadInboxBranchFilterOption[]>([]);
  const leads = ref<LeadListItem[]>([]);
  const total = ref(0);
  const selectedLeadId = ref('');
  const selectedLead = ref<LeadDetail | null>(null);

  const isListLoading = ref(false);
  const listErrorMessage = ref('');

  const isBranchesLoading = ref(false);
  const branchesErrorMessage = ref('');

  const isDetailLoading = ref(false);
  const detailErrorMessage = ref('');

  const isStatusUpdating = ref(false);
  const statusErrorMessage = ref('');
  const statusSuccessMessage = ref('');

  const hasActiveFilters = computed(() => {
    return Object.values(filters).some(Boolean);
  });
  const selectedListItem = computed(() => {
    return leads.value.find((lead) => lead.id === selectedLeadId.value) ?? null;
  });

  async function initialize() {
    await Promise.all([loadBranchOptions(), loadLeads()]);
  }

  async function loadBranchOptions() {
    isBranchesLoading.value = true;
    branchesErrorMessage.value = '';

    try {
      branchOptions.value = await fetchLeadInboxBranchOptions();
    } catch (error) {
      branchesErrorMessage.value = resolveErrorMessage(
        error,
        'Не удалось загрузить список филиалов.',
      );
    } finally {
      isBranchesLoading.value = false;
    }
  }

  async function loadLeads() {
    isListLoading.value = true;
    listErrorMessage.value = '';

    try {
      const response = await executeAuthorizedRequest((accessToken) => {
        return fetchAdminLeadList({ accessToken, filters });
      });
      leads.value = response.items;
      total.value = response.total;
      syncSelectedLeadWithList();
    } catch (error) {
      listErrorMessage.value = resolveErrorMessage(error, 'Не удалось загрузить заявки.');
    } finally {
      isListLoading.value = false;
    }
  }

  async function selectLead(leadId: string) {
    if (!leadId || isDetailLoading.value) {
      return;
    }

    if (
      leadId === selectedLeadId.value &&
      selectedLead.value &&
      !detailErrorMessage.value
    ) {
      return;
    }

    selectedLeadId.value = leadId;
    selectedLead.value = null;
    detailErrorMessage.value = '';
    statusErrorMessage.value = '';
    statusSuccessMessage.value = '';
    await loadLeadDetail(leadId);
  }

  async function resetFilters() {
    Object.assign(filters, defaultFilters());
    await loadLeads();
  }

  async function updateLeadStatus(status: LeadStatus) {
    if (!selectedLead.value || selectedLead.value.status === status) {
      return;
    }

    isStatusUpdating.value = true;
    statusErrorMessage.value = '';
    statusSuccessMessage.value = '';
    const leadId = selectedLead.value.id;

    try {
      const updatedLead = await executeAuthorizedRequest((accessToken) => {
        return updateAdminLeadStatus({
          accessToken,
          leadId,
          status,
        });
      });

      selectedLead.value = updatedLead;
      patchLeadInList(updatedLead);

      if (filters.status && filters.status !== updatedLead.status) {
        selectedLeadId.value = '';
        selectedLead.value = null;
        statusSuccessMessage.value =
          'Статус обновлен. Заявка больше не попадает под текущие фильтры.';
        await loadLeads();
        return;
      }

      statusSuccessMessage.value = 'Статус заявки обновлен.';
    } catch (error) {
      statusErrorMessage.value = resolveErrorMessage(
        error,
        'Не удалось обновить статус заявки.',
      );
    } finally {
      isStatusUpdating.value = false;
    }
  }

  async function loadLeadDetail(leadId: string) {
    isDetailLoading.value = true;
    detailErrorMessage.value = '';

    try {
      selectedLead.value = await executeAuthorizedRequest((accessToken) => {
        return fetchAdminLeadDetail({ accessToken, leadId });
      });
    } catch (error) {
      if (selectedLeadId.value === leadId) {
        detailErrorMessage.value = resolveErrorMessage(
          error,
          'Не удалось загрузить детали заявки.',
        );
      }
    } finally {
      isDetailLoading.value = false;
    }
  }

  function patchLeadInList(updatedLead: LeadDetail) {
    leads.value = leads.value.map((lead) => {
      if (lead.id !== updatedLead.id) {
        return lead;
      }

      return {
        ...lead,
        status: updatedLead.status,
        customerName: updatedLead.customerName,
        phone: updatedLead.phone,
        guestCount: updatedLead.guestCount,
        requestedDate: updatedLead.requestedDate,
        createdAt: updatedLead.createdAt,
        branch: updatedLead.branch,
        package: updatedLead.package,
        source: updatedLead.source,
        type: updatedLead.type,
      };
    });
  }

  function syncSelectedLeadWithList() {
    if (!selectedLeadId.value) {
      return;
    }

    const matchingLead = leads.value.find((lead) => lead.id === selectedLeadId.value);
    if (!matchingLead) {
      selectedLeadId.value = '';
      selectedLead.value = null;
      detailErrorMessage.value = '';
      statusErrorMessage.value = '';
      return;
    }

    if (selectedLead.value) {
      selectedLead.value = {
        ...selectedLead.value,
        ...matchingLead,
      };
    }
  }

  async function executeAuthorizedRequest<T>(
    request: (accessToken: string) => Promise<T>,
  ): Promise<T> {
    try {
      return await request(sessionStore.accessToken);
    } catch (error) {
      if (!isUnauthorized(error)) {
        throw error;
      }

      await sessionStore.refreshSession();
      return request(sessionStore.accessToken);
    }
  }

  function isUnauthorized(error: unknown): error is HttpError {
    return error instanceof HttpError && error.status === 401;
  }

  function resolveErrorMessage(error: unknown, fallback: string): string {
    if (error instanceof HttpError) {
      return error.message;
    }
    if (error instanceof Error && error.message) {
      return error.message;
    }
    return fallback;
  }

  return {
    branchOptions,
    branchesErrorMessage,
    detailErrorMessage,
    filters,
    hasActiveFilters,
    initialize,
    isBranchesLoading,
    isDetailLoading,
    isListLoading,
    isStatusUpdating,
    leads,
    listErrorMessage,
    loadLeads,
    resetFilters,
    selectLead,
    selectedLead,
    selectedLeadId,
    selectedListItem,
    statusErrorMessage,
    statusSuccessMessage,
    total,
    updateLeadStatus,
  };
}
