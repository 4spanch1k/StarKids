import { httpClient } from '@/shared/api/httpClient';

export type ScannerBranch = {
  id: string;
  name: string;
  city: string;
};

type PublicBranchResponse = ScannerBranch & {
  is_active: boolean;
};

/**
 * Scanner only needs the public active branch list. Keep this separate from
 * the admin CMS API so operators never need branch-management permissions.
 */
export async function listScannerBranches(): Promise<ScannerBranch[]> {
  const response = await httpClient<PublicBranchResponse[]>({
    path: '/mobile/branches',
    method: 'GET',
  });

  return response
    .filter((branch) => branch.is_active)
    .map(({ id, name, city }) => ({ id, name, city }));
}
