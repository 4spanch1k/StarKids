export type CustomerVisitType = 'never_visited' | 'first_visit_only' | 'returning';
export type VisitAudienceSegment = CustomerVisitType | 'dormant_30' | 'dormant_60' | 'dormant_90';

export type CustomerListItem = {
  id: string;
  firstName: string | null;
  lastName: string | null;
  phone: string | null;
  email: string | null;
  childrenCount: number;
  visitsCount: number;
  firstVisitAt: string | null;
  lastVisitAt: string | null;
  daysSinceLastVisit: number | null;
  customerVisitType: CustomerVisitType;
  ticketCashSpendTenge: number;
  bonusBalance: number;
  createdAt: string;
};

export type CustomerListResponse = {
  items: CustomerListItem[];
  total: number;
  page: number;
  pageSize: number;
};

export type CustomerBranch = {
  id: string;
  name: string;
  shortLabel: string;
};

export type CustomerChild = {
  id: string;
  name: string;
  birthDate: string;
  gender: string;
  createdAt: string;
};

export type CustomerVisit = {
  id: string;
  branch: CustomerBranch | null;
  status: string;
  startedAt: string;
  endedAt: string | null;
};

export type CustomerTicketPurchase = {
  id: string;
  localOrderId: string;
  branch: CustomerBranch | null;
  paidAt: string | null;
  visitDate: string | null;
  quantity: number;
  grossAmountTenge: number;
  bonusAmount: number;
  cashAmountTenge: number;
  currency: string;
  status: string;
};

export type CustomerLoyalty = {
  balance: number;
  lifetimeEarned: number;
  lifetimeSpent: number;
};

export type CustomerBirthdayLead = {
  id: string;
  childName: string | null;
  childBirthDate: string | null;
  desiredDate: string | null;
  branch: CustomerBranch | null;
  packageName: string | null;
  status: string;
  agreedAmountTenge: number | null;
  lostReason: string | null;
  createdAt: string;
  contactedAt: string | null;
  qualifiedAt: string | null;
  bookedAt: string | null;
  completedAt: string | null;
  lostAt: string | null;
};

export type CustomerDetail = {
  customer: {
    id: string;
    firstName: string | null;
    lastName: string | null;
    phone: string | null;
    email: string | null;
    isActive: boolean;
    createdAt: string;
  };
  metrics: {
    childrenCount: number;
    visitsCount: number;
    firstVisitAt: string | null;
    lastVisitAt: string | null;
    daysSinceLastVisit: number | null;
    customerVisitType: CustomerVisitType;
    ticketCashSpendTenge: number;
  };
  loyalty: CustomerLoyalty;
  children: CustomerChild[];
  recentVisits: CustomerVisit[];
  recentTicketPurchases: CustomerTicketPurchase[];
  birthdayLeads: CustomerBirthdayLead[];
};
