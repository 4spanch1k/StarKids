import type {
  CustomerDetail,
  CustomerListResponse,
} from '@/features/customers/model/customer';
import { httpClient } from '@/shared/api/httpClient';

const ADMIN_CUSTOMERS_BASE_PATH = '/admin/customers';

export function fetchAdminCustomerList({
  accessToken,
  search,
  page,
  pageSize,
}: {
  accessToken: string;
  search?: string;
  page: number;
  pageSize: number;
}): Promise<CustomerListResponse> {
  const query = new URLSearchParams({
    page: String(page),
    pageSize: String(pageSize),
  });
  if (search?.trim()) {
    query.set('search', search.trim());
  }

  return httpClient<CustomerListResponse>({
    path: `${ADMIN_CUSTOMERS_BASE_PATH}?${query.toString()}`,
    method: 'GET',
    headers: buildAuthorizedHeaders(accessToken),
  });
}

export function fetchAdminCustomerDetail({
  accessToken,
  customerId,
}: {
  accessToken: string;
  customerId: string;
}): Promise<CustomerDetail> {
  return httpClient<CustomerDetail>({
    path: `${ADMIN_CUSTOMERS_BASE_PATH}/${encodeURIComponent(customerId)}`,
    method: 'GET',
    headers: buildAuthorizedHeaders(accessToken),
  });
}

function buildAuthorizedHeaders(accessToken: string): HeadersInit {
  return {
    Authorization: `Bearer ${accessToken}`,
  };
}
