import { executeAuthorizedAdminRequest } from '@/features/auth/lib/adminRequest';
import { buildAdminAuthHeaders } from '@/features/auth/lib/adminRequest';
import { httpClient, HttpError } from '@/shared/api/httpClient';

export type RedemptionOutcome =
  | 'redeemed'
  | 'already_used'
  | 'invalid_qr'
  | 'ticket_not_found'
  | 'wrong_branch'
  | 'wrong_date'
  | 'invalid_status'
  | 'invalid_ticket_data'
  | 'invalid_payment';

export type TicketRedemptionResponse = {
  outcome: 'redeemed' | 'already_used';
  ticketId: string;
  ticketNumber: string;
  title: string;
  branchId: string;
  branchName: string;
  visitDate: string | null;
  status: string;
  redeemedAt: string | null;
  visitId: string | null;
};

export type TicketLookupTicket = {
  ticketId: string;
  ticketNumber: string;
  title: string;
  status: string;
  visitDate: string | null;
  redeemedAt: string | null;
  visitId: string | null;
};

export type TicketLookupOrder = {
  paymentId: string;
  localOrderId: string;
  phone: string | null;
  branchId: string;
  branchName: string;
  visitDate: string | null;
  amountTenge: number;
  status: string;
  tickets: TicketLookupTicket[];
};

export async function redeemTicket({
  qrPayload,
  branchId,
}: {
  qrPayload: string;
  branchId: string;
}): Promise<TicketRedemptionResponse> {
  return executeAuthorizedAdminRequest((accessToken) =>
    httpClient<TicketRedemptionResponse>({
      path: '/admin/tickets/redeem',
      method: 'POST',
      headers: buildAdminAuthHeaders(accessToken),
      body: JSON.stringify({ qrPayload, branchId }),
    }),
  );
}

export async function lookupTickets(query: string): Promise<TicketLookupOrder[]> {
  const response = await executeAuthorizedAdminRequest((accessToken) =>
    httpClient<{ items: TicketLookupOrder[] }>({
      path: `/admin/tickets/lookup?query=${encodeURIComponent(query.trim())}`,
      method: 'GET',
      headers: buildAdminAuthHeaders(accessToken),
    }),
  );
  return response.items;
}

export function resolveRedemptionOutcome(error: unknown): RedemptionOutcome | 'network_error' {
  if (error instanceof HttpError) {
    const payload = error.payload;
    if (isRecord(payload) && isRecord(payload.error) && typeof payload.error.code === 'string') {
      const outcome = payload.error.code;
      if (isRedemptionOutcome(outcome)) {
        return outcome;
      }
    }
    return 'network_error';
  }
  return 'network_error';
}

const REDEMPTION_OUTCOMES = new Set<RedemptionOutcome>([
  'redeemed',
  'already_used',
  'invalid_qr',
  'ticket_not_found',
  'wrong_branch',
  'wrong_date',
  'invalid_status',
  'invalid_ticket_data',
  'invalid_payment',
]);

function isRedemptionOutcome(value: string): value is RedemptionOutcome {
  return REDEMPTION_OUTCOMES.has(value as RedemptionOutcome);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}
