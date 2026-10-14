import { computed, reactive, ref } from 'vue';

import type {
  LeadDetail,
  LeadListFilters,
  LeadListItem,
  LeadStatus,
  LeadStatusUpdate,
} from '@/entities/lead/model/lead';
import {
  executeAuthorizedAdminRequest,
  resolveAdminRequestError,
} from '@/features/auth/lib/adminRequest';
import {
  fetchAdminBirthdayLeadDetail,
  fetchAdminLeadDetail,
  fetchAdminLeadList,
  fetchBirthdayOperationsSummary,
  fetchLeadInboxBranchOptions,
  type BirthdayOperationsSummary,
  type LeadInboxBranchFilterOption,
  updateAdminLeadStatus,
} from '@/features/leads/api/adminLeadInboxApi';

const defaultFilters = (): LeadListFilters => ({
  branchId: '',
  status: '',
  createdFrom: '',
  createdTo: '',
  awaitingContact: '',
  sort: 'newest',
});

export function useLeadInbox() {
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
  const summaryPeriod = ref<BirthdayOperationsSummary['period']>('today');
  const operationsSummary = ref<BirthdayOperationsSummary | null>(null);
  const isSummaryLoading = ref(false);
  const summaryErrorMessage = ref('');

  const hasActiveFilters = computed(() => {
    return Boolean(
      filters.branchId ||
      filters.status ||
      filters.createdFrom ||
      filters.createdTo ||
      filters.awaitingContact === 'true' ||
      filters.sort !== 'newest',
    );
  });
  const selectedListItem = computed(() => {
    return leads.value.find((lead) => lead.id === selectedLeadId.value) ?? null;
  });

  async function initialize() {
    await Promise.all([loadBranchOptions(), loadLeads(), loadOperationsSummary()]);
  }

  async function loadBranchOptions() {
    isBranchesLoading.value = true;
    branchesErrorMessage.value = '';

    try {
      branchOptions.value = await executeAuthorizedAdminRequest((accessToken) => {
        return fetchLeadInboxBranchOptions({ accessToken });
      });
    } catch (error) {
      branchesErrorMessage.value = resolveAdminRequestError(
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
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return fetchAdminLeadList({ accessToken, filters });
      });
      leads.value = response.items;
      total.value = response.total;
      syncSelectedLeadWithList();

      if (leads.value.length > 0 && !selectedLeadId.value) {
        await selectLead(leads.value[0].id);
      }
    } catch (error) {
      listErrorMessage.value = resolveAdminRequestError(error, 'Не удалось загрузить заявки.');
    } finally {
      isListLoading.value = false;
    }
  }

  async function loadOperationsSummary(
    period: BirthdayOperationsSummary['period'] = summaryPeriod.value,
  ) {
    summaryPeriod.value = period;
    isSummaryLoading.value = true;
    summaryErrorMessage.value = '';
    try {
      operationsSummary.value = await executeAuthorizedAdminRequest((accessToken) =>
        fetchBirthdayOperationsSummary({ accessToken, period }),
      );
    } catch (error) {
      summaryErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить сводку по скорости обработки заявок.',
      );
    } finally {
      isSummaryLoading.value = false;
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

  async function updateLeadStatus(update: LeadStatus | LeadStatusUpdate) {
    const status = typeof update === 'string' ? update : update.status;
    const salesFields: LeadStatusUpdate =
      typeof update === 'string' ? { status } : update;
    if (!selectedLead.value || selectedLead.value.status === status) {
      if (
        !selectedLead.value ||
        selectedLead.value.type !== 'birthday_request' ||
        typeof update === 'string' ||
        (update.agreedAmountTenge === undefined &&
          update.expectedAmountTenge === undefined &&
          update.depositAmountTenge === undefined &&
          update.paidAmountTenge === undefined &&
          update.lostReason === undefined)
      ) {
        return;
      }
    }

    isStatusUpdating.value = true;
    statusErrorMessage.value = '';
    statusSuccessMessage.value = '';
    const leadId = selectedLead.value.id;

    try {
      const updatedLead = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminLeadStatus({
          accessToken,
          leadId,
          status,
          agreedAmountTenge: salesFields.agreedAmountTenge,
          expectedAmountTenge: salesFields.expectedAmountTenge,
          depositAmountTenge: salesFields.depositAmountTenge,
          paidAmountTenge: salesFields.paidAmountTenge,
          lostReason: salesFields.lostReason,
        });
      });

      if (selectedLead.value.type === 'birthday_request') {
        await loadLeadDetail(leadId);
      } else {
        selectedLead.value = {
          ...selectedLead.value,
          ...updatedLead,
        };
      }
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
      statusErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось обновить статус заявки.',
      );
    } finally {
      isStatusUpdating.value = false;
    }
  }

  async function updateLeadNote(note: string) {
    if (!selectedLead.value || selectedLead.value.type !== 'birthday_request') {
      return;
    }

    isStatusUpdating.value = true;
    statusErrorMessage.value = '';
    statusSuccessMessage.value = '';
    const leadId = selectedLead.value.id;
    const currentStatus = selectedLead.value.status;

    try {
      const updatedLead = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminLeadStatus({
          accessToken,
          leadId,
          status: currentStatus,
          adminNote: note,
        });
      });
      selectedLead.value = {
        ...selectedLead.value,
        ...updatedLead,
        adminNote: note,
      };
      statusSuccessMessage.value = 'Внутренняя заметка сохранена.';
    } catch (error) {
      statusErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить внутреннюю заметку.',
      );
    } finally {
      isStatusUpdating.value = false;
    }
  }

  async function quickUpdateLeadStatus(leadId: string, status: LeadStatus) {
    const currentLead = leads.value.find((lead) => lead.id === leadId);
    if (!currentLead || currentLead.status === status || isStatusUpdating.value) {
      return;
    }

    isStatusUpdating.value = true;
    statusErrorMessage.value = '';
    statusSuccessMessage.value = '';

    try {
      const updatedLead = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminLeadStatus({
          accessToken,
          leadId,
          status,
        });
      });

      patchLeadInList(updatedLead);

      if (selectedLeadId.value === leadId) {
        selectedLead.value = {
          ...selectedLead.value,
          ...updatedLead,
        };
      }

      if (filters.status && filters.status !== updatedLead.status) {
        if (selectedLeadId.value === leadId) {
          selectedLeadId.value = '';
          selectedLead.value = null;
        }
        statusSuccessMessage.value =
          'Статус обновлен. Заявка больше не попадает под текущие фильтры.';
        await loadLeads();
        return;
      }

      statusSuccessMessage.value = 'Статус заявки обновлен.';
    } catch (error) {
      statusErrorMessage.value = resolveAdminRequestError(
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
      const baseLead = await executeAuthorizedAdminRequest((accessToken) => {
        return fetchAdminLeadDetail({ accessToken, leadId });
      });
      if (baseLead.type === 'birthday_request') {
        selectedLead.value = await executeAuthorizedAdminRequest((accessToken) => {
          return fetchAdminBirthdayLeadDetail({ accessToken, leadId });
        });
      } else {
        selectedLead.value = baseLead;
      }
    } catch (error) {
      if (selectedLeadId.value === leadId) {
        detailErrorMessage.value = resolveAdminRequestError(
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
        summary: updatedLead.summary,
        status: updatedLead.status,
        customerName: updatedLead.customerName,
        phone: updatedLead.phone,
        guestCount: updatedLead.guestCount,
        requestedDate: updatedLead.requestedDate,
        createdAt: updatedLead.createdAt,
        waitingForContactMinutes: updatedLead.waitingForContactMinutes,
        firstContactMinutes: updatedLead.firstContactMinutes,
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
    isSummaryLoading,
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
    operationsSummary,
    loadOperationsSummary,
    summaryErrorMessage,
    summaryPeriod,
    total,
    quickUpdateLeadStatus,
    updateLeadStatus,
    updateLeadNote,
  };
}
