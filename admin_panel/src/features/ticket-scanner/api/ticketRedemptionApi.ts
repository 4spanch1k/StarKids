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
  | 'invalid_ticket_data';

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
]);

function isRedemptionOutcome(value: string): value is RedemptionOutcome {
  return REDEMPTION_OUTCOMES.has(value as RedemptionOutcome);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}
