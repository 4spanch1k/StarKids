export const leadStatuses = ['new', 'in_progress', 'closed'] as const;

export type LeadStatus = (typeof leadStatuses)[number];
export type LeadType = 'birthday_request';

export type LeadBranchSummary = {
  id: string;
  name: string;
  shortLabel: string;
};

export type LeadPackageSummary = {
  id: string;
  name: string;
};

export type LeadListFilters = {
  branchId: string;
  status: LeadStatus | '';
  createdFrom: string;
  createdTo: string;
};

export type LeadListItem = {
  id: string;
  type: LeadType;
  status: LeadStatus;
  source: string;
  customerName: string;
  phone: string;
  guestCount: number | null;
  requestedDate: string | null;
  createdAt: string;
  branch: LeadBranchSummary;
  package: LeadPackageSummary | null;
};

export type LeadListResponse = {
  items: LeadListItem[];
  total: number;
};

export type LeadDetail = LeadListItem & {
  notes: string | null;
  contactMethod: string;
};
