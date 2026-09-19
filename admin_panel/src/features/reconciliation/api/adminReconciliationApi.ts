import type { ReconciliationResponse } from '@/features/reconciliation/model/reconciliation';
import { httpClient } from '@/shared/api/httpClient';

export function fetchReconciliationItems({
  accessToken,
}: {
  accessToken: string;
}): Promise<ReconciliationResponse> {
  return httpClient<ReconciliationResponse>({
    path: '/admin/reconciliation',
    method: 'GET',
    headers: { Authorization: `Bearer ${accessToken}` },
  });
}
