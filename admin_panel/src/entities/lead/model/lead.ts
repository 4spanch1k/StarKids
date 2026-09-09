export const leadStatuses = [
  'new',
  'contacted',
  'qualified',
  'booked',
  'paid',
  'completed',
  'lost',
  'in_progress',
  'confirmed',
  'cancelled',
  'closed',
] as const;

export type LeadStatus = (typeof leadStatuses)[number];
export type LeadType = 'birthday_request' | 'contact';

export const leadStatusLabels: Record<LeadStatus, string> = {
  new: 'Новая',
  contacted: 'Менеджер связался',
  qualified: 'Квалифицирована',
  booked: 'Забронировано',
  paid: 'Оплачено',
  completed: 'Проведено',
  lost: 'Не состоялось',
  in_progress: 'В работе',
  confirmed: 'Праздник подтверждён',
  cancelled: 'Отменено',
  closed: 'Закрыта',
};

export const leadStatusTransitions: Record<LeadStatus, LeadStatus[]> = {
  new: ['new', 'in_progress', 'contacted', 'confirmed', 'cancelled', 'closed', 'lost'],
  contacted: ['contacted', 'qualified', 'confirmed', 'cancelled', 'lost'],
  qualified: ['qualified', 'booked', 'lost'],
  booked: ['booked', 'paid', 'completed', 'lost'],
  paid: ['paid', 'completed', 'lost'],
  completed: ['completed'],
  lost: ['lost', 'contacted', 'qualified'],
  in_progress: ['in_progress', 'contacted', 'qualified', 'booked', 'confirmed', 'cancelled', 'lost', 'closed'],
  confirmed: ['confirmed', 'completed', 'lost'],
  cancelled: ['cancelled'],
  closed: ['closed'],
};

export const lostReasonOptions = [
  { value: 'too_expensive', label: 'Слишком дорого' },
  { value: 'date_unavailable', label: 'Дата занята' },
  { value: 'no_answer', label: 'Не дозвонились' },
  { value: 'competitor', label: 'Выбрали конкурента' },
  { value: 'changed_mind', label: 'Передумали' },
  { value: 'other_branch', label: 'Выбрали другой филиал' },
  { value: 'later', label: 'Отложили на потом' },
  { value: 'other', label: 'Другое' },
  { value: 'price', label: 'Слишком дорого' },
  { value: 'no_response', label: 'Не дозвонились' },
  { value: 'chose_competitor', label: 'Выбрали конкурента' },
  { value: 'changed_plans', label: 'Изменили планы' },
  { value: 'duplicate', label: 'Дубликат заявки' },
] as const;

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
  awaitingContact: '' | 'true';
  sort: 'newest' | 'oldest_uncontacted';
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
  waitingForContactMinutes: number | null;
  firstContactMinutes: number | null;
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
  childId?: string | null;
  childName?: string | null;
  childBirthDate?: string | null;
  packageNameSnapshot?: string | null;
  packagePriceSnapshot?: number | null;
  adminNote?: string | null;
  updatedAt?: string | null;
  contactedAt?: string | null;
  closedAt?: string | null;
  agreedAmountTenge?: number | null;
  expectedAmountTenge?: number | null;
  depositAmountTenge?: number | null;
  paidAmountTenge?: number | null;
  lostReason?: string | null;
  qualifiedAt?: string | null;
  bookedAt?: string | null;
  completedAt?: string | null;
  lostAt?: string | null;
  paidAt?: string | null;
};

export type LeadStatusUpdate = {
  status: LeadStatus;
  agreedAmountTenge?: number | null;
  expectedAmountTenge?: number | null;
  depositAmountTenge?: number | null;
  paidAmountTenge?: number | null;
  lostReason?: string | null;
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

  if (status === 'contacted') {
    return 'Менеджер связался с родителем: можно квалифицировать интерес или закрыть заявку.';
  }

  if (status === 'qualified') {
    return 'Потребность подтверждена: согласуйте дату, пакет и стоимость.';
  }

  if (status === 'booked') {
    return 'Дата и пакет согласованы. После получения оплаты переведите заявку в «Оплачено».';
  }

  if (status === 'paid') {
    return 'Оплата зафиксирована. После проведения переведите заявку в «Проведено».';
  }

  if (status === 'completed') {
    return 'Праздник состоялся: заявка доступна только для просмотра.';
  }

  if (status === 'confirmed') {
    return 'Праздник подтверждён: заявка доступна только для просмотра.';
  }

  if (status === 'cancelled' || status === 'closed') {
    return 'Заявка завершена: обратные переходы не поддерживаются.';
  }

  if (status === 'lost') {
    return 'Заявка потеряна. Если клиент вернулся, можно вернуть её в работу.';
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
