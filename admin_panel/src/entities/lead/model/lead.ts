export const leadStatuses = ['new', 'in_progress', 'closed'] as const;

export type LeadStatus = (typeof leadStatuses)[number];
export type LeadType = 'birthday_request' | 'contact';

export const leadStatusLabels: Record<LeadStatus, string> = {
  new: 'Новая',
  in_progress: 'В работе',
  closed: 'Закрыта',
};

export const leadStatusTransitions: Record<LeadStatus, LeadStatus[]> = {
  new: ['new', 'in_progress', 'closed'],
  in_progress: ['in_progress', 'closed'],
  closed: ['closed'],
};

export const leadTypeLabels: Record<LeadType, string> = {
  birthday_request: 'День рождения',
  contact: 'Связь с менеджером',
};

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
  summary: string;
  status: LeadStatus;
  source: string;
  customerName: string;
  phone: string;
  guestCount: number | null;
  requestedDate: string | null;
  createdAt: string;
  branch: LeadBranchSummary | null;
  package: LeadPackageSummary | null;
};

export type LeadListResponse = {
  items: LeadListItem[];
  total: number;
};

export type LeadDetail = LeadListItem & {
  email: string | null;
  notes: string | null;
  contactMethod: string;
};

export function formatLeadStatus(status: LeadStatus): string {
  return leadStatusLabels[status];
}

export function formatLeadType(type: LeadType): string {
  return leadTypeLabels[type];
}

export function isLeadStatusTransitionAllowed(
  currentStatus: LeadStatus,
  nextStatus: LeadStatus,
): boolean {
  return leadStatusTransitions[currentStatus].includes(nextStatus);
}

export function describeLeadStatusFlow(status: LeadStatus): string {
  if (status === 'new') {
    return 'Новая заявка: можно перевести в работу или сразу закрыть без лишних шагов.';
  }

  if (status === 'in_progress') {
    return 'Заявка уже в работе: доступно только закрытие, возврат в "Новая" не поддерживается.';
  }

  return 'Заявка закрыта: статус остается только для просмотра, обратные переходы не поддерживаются.';
}

export function isLeadStatusActionEnabled(
  currentStatus: LeadStatus,
  nextStatus: LeadStatus,
): boolean {
  if (currentStatus === nextStatus) {
    return false;
  }

  return isLeadStatusTransitionAllowed(currentStatus, nextStatus);
}
