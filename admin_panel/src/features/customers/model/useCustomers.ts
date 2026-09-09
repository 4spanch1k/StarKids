import { computed, ref } from 'vue';

import {
  fetchAdminCustomerDetail,
  fetchAdminCustomerList,
} from '@/features/customers/api/adminCustomersApi';
import type {
  CustomerDetail,
  CustomerListItem,
  VisitAudienceSegment,
} from '@/features/customers/model/customer';
import {
  executeAuthorizedAdminRequest,
  resolveAdminRequestError,
} from '@/features/auth/lib/adminRequest';

export function useCustomers() {
  const search = ref('');
  const visitSegment = ref<VisitAudienceSegment | ''>('');
  const items = ref<CustomerListItem[]>([]);
  const total = ref(0);
  const page = ref(1);
  const pageSize = 25;
  const selectedCustomerId = ref('');
  const selectedCustomer = ref<CustomerDetail | null>(null);

  const isListLoading = ref(false);
  const isDetailLoading = ref(false);
  const listErrorMessage = ref('');
  const detailErrorMessage = ref('');

  const totalPages = computed(() => Math.max(1, Math.ceil(total.value / pageSize)));
  const hasPreviousPage = computed(() => page.value > 1);
  const hasNextPage = computed(() => page.value < totalPages.value);

  async function initialize() {
    await loadCustomers(1);
  }

  async function loadCustomers(nextPage: number) {
    isListLoading.value = true;
    listErrorMessage.value = '';
    const requestedPage = Math.max(1, Math.min(nextPage, totalPages.value));

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) =>
        fetchAdminCustomerList({
          accessToken,
          search: search.value,
          page: requestedPage,
          pageSize,
          visitSegment: visitSegment.value,
        }),
      );
      items.value = response.items;
      total.value = response.total;
      page.value = response.page;
      if (
        selectedCustomerId.value &&
        !items.value.some((item) => item.id === selectedCustomerId.value)
      ) {
        selectedCustomerId.value = '';
        selectedCustomer.value = null;
      }
    } catch (error) {
      listErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить список клиентов.',
      );
    } finally {
      isListLoading.value = false;
    }
  }

  async function applySearch() {
    await loadCustomers(1);
  }

  async function selectCustomer(customerId: string) {
    if (!customerId || isDetailLoading.value) {
      return;
    }
    if (
      customerId === selectedCustomerId.value &&
      selectedCustomer.value &&
      !detailErrorMessage.value
    ) {
      return;
    }

    selectedCustomerId.value = customerId;
    selectedCustomer.value = null;
    detailErrorMessage.value = '';
    isDetailLoading.value = true;

    try {
      selectedCustomer.value = await executeAuthorizedAdminRequest((accessToken) =>
        fetchAdminCustomerDetail({ accessToken, customerId }),
      );
    } catch (error) {
      if (selectedCustomerId.value === customerId) {
        detailErrorMessage.value = resolveAdminRequestError(
          error,
          'Не удалось открыть карточку клиента.',
        );
      }
    } finally {
      isDetailLoading.value = false;
    }
  }

  function clearSelection() {
    selectedCustomerId.value = '';
    selectedCustomer.value = null;
    detailErrorMessage.value = '';
  }

  return {
    applySearch,
    clearSelection,
    detailErrorMessage,
    hasNextPage,
    hasPreviousPage,
    initialize,
    isDetailLoading,
    isListLoading,
    items,
    listErrorMessage,
    loadCustomers,
    page,
    pageSize,
    search,
    visitSegment,
    selectedCustomer,
    selectedCustomerId,
    total,
    totalPages,
    selectCustomer,
  };
}
