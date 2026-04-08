import { buildAdminAuthHeaders } from '@/features/auth/lib/adminRequest';
import type {
  AdminBirthdayPackageCreatePayload,
  AdminBirthdayPackageDetail,
  AdminBirthdayPackageSummary,
  AdminBirthdayPackageUpdatePayload,
} from '@/features/birthday-packages/model/adminBirthdayPackage';
import { httpClient } from '@/shared/api/httpClient';

const ADMIN_BIRTHDAY_PACKAGES_BASE_PATH = '/admin/birthday-packages';

type AuthorizedRequest = {
  accessToken: string;
};

type AdminBirthdayPackageResponse = {
  id: string;
  branch_id: string;
  slug: string;
  name: string;
  price_from: number;
  price_label: string;
  guest_capacity_label: string;
  image_url: string | null;
  is_featured: boolean;
  is_active: boolean;
  display_order: number;
  description?: string;
  highlights?: string[];
};

export async function listAdminBirthdayPackages({
  accessToken,
  branchId,
  includeInactive = true,
}: AuthorizedRequest & {
  branchId?: string;
  includeInactive?: boolean;
}): Promise<AdminBirthdayPackageSummary[]> {
  const query = new URLSearchParams();
  if (branchId) {
    query.set('branch_id', branchId);
  }
  if (includeInactive) {
    query.set('include_inactive', 'true');
  }

  const querySuffix = query.size ? `?${query.toString()}` : '';
  const response = await httpClient<AdminBirthdayPackageResponse[]>({
    path: `${ADMIN_BIRTHDAY_PACKAGES_BASE_PATH}${querySuffix}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return response.map(mapPackageSummary);
}

export async function getAdminBirthdayPackage({
  accessToken,
  packageId,
}: AuthorizedRequest & { packageId: string }): Promise<AdminBirthdayPackageDetail> {
  const response = await httpClient<AdminBirthdayPackageResponse>({
    path: `${ADMIN_BIRTHDAY_PACKAGES_BASE_PATH}/${packageId}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return mapPackageDetail(response);
}

export async function createAdminBirthdayPackage({
  accessToken,
  payload,
}: AuthorizedRequest & {
  payload: AdminBirthdayPackageCreatePayload;
}): Promise<AdminBirthdayPackageDetail> {
  const response = await httpClient<AdminBirthdayPackageResponse>({
    path: ADMIN_BIRTHDAY_PACKAGES_BASE_PATH,
    method: 'POST',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializePackagePayload(payload)),
  });

  return mapPackageDetail(response);
}

export async function updateAdminBirthdayPackage({
  accessToken,
  packageId,
  payload,
}: AuthorizedRequest & {
  packageId: string;
  payload: AdminBirthdayPackageUpdatePayload;
}): Promise<AdminBirthdayPackageDetail> {
  const response = await httpClient<AdminBirthdayPackageResponse>({
    path: `${ADMIN_BIRTHDAY_PACKAGES_BASE_PATH}/${packageId}`,
    method: 'PATCH',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializePackagePayload(payload)),
  });

  return mapPackageDetail(response);
}

function mapPackageSummary(
  response: AdminBirthdayPackageResponse,
): AdminBirthdayPackageSummary {
  return {
    id: response.id,
    branchId: response.branch_id,
    slug: response.slug,
    name: response.name,
    priceFrom: response.price_from,
    priceLabel: response.price_label,
    guestCapacityLabel: response.guest_capacity_label,
    imageUrl: response.image_url ?? '',
    isFeatured: response.is_featured,
    isActive: response.is_active,
    displayOrder: response.display_order,
  };
}

function mapPackageDetail(
  response: AdminBirthdayPackageResponse,
): AdminBirthdayPackageDetail {
  return {
    ...mapPackageSummary(response),
    description: response.description ?? '',
    highlights: response.highlights ?? [],
  };
}

function serializePackagePayload(
  payload: AdminBirthdayPackageCreatePayload | AdminBirthdayPackageUpdatePayload,
): Record<string, unknown> {
  return {
    branch_id: payload.branchId,
    slug: payload.slug,
    name: payload.name,
    price_from: payload.priceFrom,
    price_label: payload.priceLabel,
    guest_capacity_label: payload.guestCapacityLabel,
    description: payload.description,
    highlights: payload.highlights,
    image_url: payload.imageUrl || null,
    is_featured: payload.isFeatured,
    is_active: payload.isActive,
    display_order: payload.displayOrder,
  };
}
