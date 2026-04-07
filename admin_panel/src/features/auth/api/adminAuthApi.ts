import { httpClient } from '@/shared/api/httpClient';

import type {
  AdminAuthResponse,
  AdminCurrentUser,
  AdminLoginPayload,
  AdminRefreshPayload,
} from '@/features/auth/types';

const ADMIN_AUTH_BASE_PATH = '/admin/auth';

export function loginAdmin(payload: AdminLoginPayload): Promise<AdminAuthResponse> {
  return httpClient<AdminAuthResponse>({
    path: `${ADMIN_AUTH_BASE_PATH}/login`,
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function refreshAdminSession(
  payload: AdminRefreshPayload,
): Promise<AdminAuthResponse> {
  return httpClient<AdminAuthResponse>({
    path: `${ADMIN_AUTH_BASE_PATH}/refresh`,
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function fetchCurrentAdminUser(accessToken: string): Promise<AdminCurrentUser> {
  return httpClient<AdminCurrentUser>({
    path: `${ADMIN_AUTH_BASE_PATH}/current-user`,
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });
}
