import { buildAdminAuthHeaders, executeAuthorizedAdminRequest } from '@/features/auth/lib/adminRequest';
import { httpClient } from '@/shared/api/httpClient';

export type AdminStaffMember = {
  id: string;
  email: string;
  full_name: string;
  role: string;
  is_active: boolean;
  branch_id: string | null;
  branch_name: string | null;
};

export async function fetchAdminStaff(): Promise<AdminStaffMember[]> {
  const response = await executeAuthorizedAdminRequest((accessToken) =>
    httpClient<{ items: AdminStaffMember[] }>({
      path: '/admin/staff',
      method: 'GET',
      headers: buildAdminAuthHeaders(accessToken),
    }),
  );
  return response.items;
}

export function updateAdminStaffBranch(
  adminUserId: string,
  branchId: string | null,
): Promise<AdminStaffMember> {
  return executeAuthorizedAdminRequest((accessToken) =>
    httpClient<AdminStaffMember>({
      path: `/admin/staff/${encodeURIComponent(adminUserId)}/branch`,
      method: 'PATCH',
      headers: buildAdminAuthHeaders(accessToken),
      body: JSON.stringify({ branch_id: branchId }),
    }),
  );
}
