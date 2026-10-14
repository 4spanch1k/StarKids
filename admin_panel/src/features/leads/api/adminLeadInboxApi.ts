import type {
  LeadDetail,
  LeadListFilters,
  LeadListResponse,
  LeadStatusUpdate,
} from '@/entities/lead/model/lead';
import { httpClient } from '@/shared/api/httpClient';

const ADMIN_LEADS_BASE_PATH = '/admin/leads';
const ADMIN_BRANCHES_BASE_PATH = '/admin/branches';

type AuthorizedRequest = {
  accessToken: string;
};

type FetchLeadListRequest = AuthorizedRequest & {
  filters: LeadListFilters;
};

export type BirthdayOperationsSummary = {
  period: 'today' | '7d' | '30d';
  periodStart: string;
  periodEnd: string;
  timezone: string;
  newAwaitingContact: number;
  oldestWaitingMinutes: number | null;
  leadsCreated: number;
  contactedFromCreatedLeads: number;
  medianFirstContactMinutes: number | null;
  p90FirstContactMinutes: number | null;
};

type UpdateLeadStatusRequest = AuthorizedRequest & LeadStatusUpdate & {
  leadId: string;
  adminNote?: string;
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
  if (filters.awaitingContact) {
    query.set('awaitingContact', 'true');
  }
  if (filters.sort !== 'newest') {
    query.set('sort', filters.sort);
  }

  const querySuffix = query.size > 0 ? `?${query.toString()}` : '';
  return httpClient<LeadListResponse>({
    path: `${ADMIN_LEADS_BASE_PATH}${querySuffix}`,
    method: 'GET',
    headers: buildAuthorizedHeaders(accessToken),
  });
}

export function fetchBirthdayOperationsSummary({
  accessToken,
  period,
}: AuthorizedRequest & { period: BirthdayOperationsSummary['period'] }): Promise<BirthdayOperationsSummary> {
  return httpClient<BirthdayOperationsSummary>({
    path: `/admin/leads/birthday/operations-summary?period=${encodeURIComponent(period)}`,
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

type BirthdayLeadDetailResponse = LeadDetail & {
  childId?: string | null;
  childName?: string | null;
  childBirthDate?: string | null;
  packageNameSnapshot?: string | null;
  packagePriceSnapshot?: number | null;
  comment?: string | null;
  contactMethod?: string;
  adminNote?: string | null;
  updatedAt?: string | null;
  contactedAt?: string | null;
  agreedAmountTenge?: number | null;
  expectedAmountTenge?: number | null;
  depositAmountTenge?: number | null;
  paidAmountTenge?: number | null;
  lostReason?: string | null;
  qualifiedAt?: string | null;
  bookedAt?: string | null;
  completedAt?: string | null;
  lostAt?: string | null;
  closedAt?: string | null;
};

export async function fetchAdminBirthdayLeadDetail({
  accessToken,
  leadId,
}: AuthorizedRequest & { leadId: string }): Promise<LeadDetail> {
  const response = await httpClient<BirthdayLeadDetailResponse>({
    path: `${ADMIN_LEADS_BASE_PATH}/${leadId}/birthday`,
    method: 'GET',
    headers: buildAuthorizedHeaders(accessToken),
  });

  return {
    ...response,
    email: response.email ?? null,
    notes: response.comment ?? null,
    contactMethod: response.contactMethod ?? 'phone',
    childId: response.childId ?? null,
    childName: response.childName ?? null,
    childBirthDate: response.childBirthDate ?? null,
    packageNameSnapshot: response.packageNameSnapshot ?? null,
    packagePriceSnapshot: response.packagePriceSnapshot ?? null,
    adminNote: response.adminNote ?? null,
    updatedAt: response.updatedAt ?? null,
    contactedAt: response.contactedAt ?? null,
    agreedAmountTenge: response.agreedAmountTenge ?? null,
    expectedAmountTenge: response.expectedAmountTenge ?? response.agreedAmountTenge ?? null,
    depositAmountTenge: response.depositAmountTenge ?? null,
    paidAmountTenge: response.paidAmountTenge ?? null,
    lostReason: response.lostReason ?? null,
    qualifiedAt: response.qualifiedAt ?? null,
    bookedAt: response.bookedAt ?? null,
    completedAt: response.completedAt ?? null,
    lostAt: response.lostAt ?? null,
    closedAt: response.closedAt ?? null,
    paidAt: response.paidAt ?? null,
  };
}

export function updateAdminLeadStatus({
  accessToken,
  leadId,
  status,
  agreedAmountTenge,
  expectedAmountTenge,
  depositAmountTenge,
  paidAmountTenge,
  lostReason,
  adminNote,
}: UpdateLeadStatusRequest): Promise<LeadDetail> {
  return httpClient<LeadDetail>({
    path: `${ADMIN_LEADS_BASE_PATH}/${leadId}/status`,
    method: 'PATCH',
    headers: buildAuthorizedHeaders(accessToken),
    body: JSON.stringify({
      status,
      ...(adminNote !== undefined ? { adminNote } : {}),
      ...(agreedAmountTenge !== undefined ? { agreedAmountTenge } : {}),
      ...(expectedAmountTenge !== undefined ? { expectedAmountTenge } : {}),
      ...(depositAmountTenge !== undefined ? { depositAmountTenge } : {}),
      ...(paidAmountTenge !== undefined ? { paidAmountTenge } : {}),
      ...(lostReason !== undefined ? { lostReason } : {}),
    }),
  });
}

export async function fetchLeadInboxBranchOptions({
  accessToken,
}: AuthorizedRequest): Promise<LeadInboxBranchFilterOption[]> {
  const branches = await httpClient<BranchSummaryResponse[]>({
    path: `${ADMIN_BRANCHES_BASE_PATH}?include_inactive=true`,
    method: 'GET',
    headers: buildAuthorizedHeaders(accessToken),
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
