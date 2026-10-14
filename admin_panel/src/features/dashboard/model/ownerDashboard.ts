export type OwnerDashboardPeriod = 'today' | '7d' | '30d';

export type OwnerDashboard = {
  period: OwnerDashboardPeriod;
  periodStart: string;
  periodEnd: string;
  timezone: string;
  ticketCashCollectedTenge: number;
  paidTicketPurchases: number;
  ticketsSold: number;
  visits: number;
  newFamilies: number;
  returningFamilies: number;
  bonusesIssued: number;
  bonusesRedeemed: number;
  outstandingBonusBalance: number;
};
