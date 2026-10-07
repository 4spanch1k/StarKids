export type ReconciliationItem = {
  paymentId: string;
  localOrderId: string;
  createdAt: string;
  paidAt: string | null;
  branchId: string;
  branchName: string;
  customer: string;
  amountTenge: number;
  issueType: string;
  lastFailure: string | null;
  ticketIssuancePending: boolean;
  loyaltySettlementPending: boolean;
  callbackMismatch: boolean;
};

export type ReconciliationResponse = {
  items: ReconciliationItem[];
  total: number;
};
