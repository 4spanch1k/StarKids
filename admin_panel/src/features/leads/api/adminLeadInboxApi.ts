import type {
  LeadDetail,
  LeadListFilters,
  LeadListResponse,
  LeadStatus,
} from '@/entities/lead/model/lead';
import { httpClient } from '@/shared/api/httpClient';

const ADMIN_LEADS_BASE_PATH = '/admin/leads';
const MOBILE_BRANCHES_BASE_PATH = '/mobile/branches';

type AuthorizedRequest = {
  accessToken: string;
};

type FetchLeadListRequest = AuthorizedRequest & {
  filters: LeadListFilters;
};

type UpdateLeadStatusRequest = AuthorizedRequest & {
  leadId: string;
  status: LeadStatus;
};

type BranchSummaryResponse = {
  id: string;
  name: string;
  short_label: string;
  is_active: boolean;
};

export type LeadInboxBranchFilterOption = {
  id: string;
  name: string;
  shortLabel: string;
  isActive: boolean;
};

export function fetchAdminLeadList({
  accessToken,
  filters,
}: FetchLeadListRequest): Promise<LeadListResponse> {
  const query = new URLSearchParams();

  if (filters.branchId) {
    query.set('branchId', filters.branchId);
  }
  if (filters.status) {
    query.set('status', filters.status);
  }
  if (filters.createdFrom) {
    query.set('createdFrom', filters.createdFrom);
  }
  if (filters.createdTo) {
    query.set('createdTo', filters.createdTo);
  }

  const querySuffix = query.size > 0 ? `?${query.toString()}` : '';
  return httpClient<LeadListResponse>({
    path: `${ADMIN_LEADS_BASE_PATH}${querySuffix}`,
    method: 'GET',
    headers: buildAuthorizedHeaders(accessToken),
  });
}

export function fetchAdminLeadDetail({
  accessToken,
  leadId,
}: AuthorizedRequest & { leadId: string }): Promise<LeadDetail> {
  return httpClient<LeadDetail>({
    path: `${ADMIN_LEADS_BASE_PATH}/${leadId}`,
    method: 'GET',
    headers: buildAuthorizedHeaders(accessToken),
  });
}

export function updateAdminLeadStatus({
  accessToken,
  leadId,
  status,
}: UpdateLeadStatusRequest): Promise<LeadDetail> {
  return httpClient<LeadDetail>({
    path: `${ADMIN_LEADS_BASE_PATH}/${leadId}/status`,
    method: 'PATCH',
    headers: buildAuthorizedHeaders(accessToken),
    body: JSON.stringify({ status }),
  });
}

export async function fetchLeadInboxBranchOptions(): Promise<
  LeadInboxBranchFilterOption[]
> {
  const branches = await httpClient<BranchSummaryResponse[]>({
    path: MOBILE_BRANCHES_BASE_PATH,
    method: 'GET',
  });

  return branches.map((branch) => ({
    id: branch.id,
    name: branch.name,
    shortLabel: branch.short_label,
    isActive: branch.is_active,
  }));
}

function buildAuthorizedHeaders(accessToken: string): HeadersInit {
  return {
    Authorization: `Bearer ${accessToken}`,
  };
}
