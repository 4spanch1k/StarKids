import type {
  OwnerDashboard,
  OwnerDashboardPeriod,
} from '@/features/dashboard/model/ownerDashboard';
import { httpClient } from '@/shared/api/httpClient';

const OWNER_DASHBOARD_PATH = '/admin/dashboard/owner';

export function fetchOwnerDashboard({
  accessToken,
  period,
}: {
  accessToken: string;
  period: OwnerDashboardPeriod;
}): Promise<OwnerDashboard> {
  const query = new URLSearchParams({ period });
  return httpClient<OwnerDashboard>({
    path: `${OWNER_DASHBOARD_PATH}?${query.toString()}`,
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });
}
