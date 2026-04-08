import { buildAdminAuthHeaders } from '@/features/auth/lib/adminRequest';
import type {
  AdminPromotion,
  AdminPromotionCreatePayload,
  AdminPromotionUpdatePayload,
} from '@/features/promotions/model/adminPromotion';
import { httpClient } from '@/shared/api/httpClient';

const ADMIN_PROMOTIONS_BASE_PATH = '/admin/promotions';

type AuthorizedRequest = {
  accessToken: string;
};

type AdminPromotionResponse = {
  id: string;
  title: string;
  description: string;
  badge_label: string;
  image_url: string | null;
  branch_ids: string[];
  cta_label: string;
  display_order: number;
  is_active: boolean;
  is_published: boolean;
};

export async function listAdminPromotions({
  accessToken,
  branchId,
  isActive,
  isPublished,
}: AuthorizedRequest & {
  branchId?: string;
  isActive?: boolean | '';
  isPublished?: boolean | '';
}): Promise<AdminPromotion[]> {
  const query = new URLSearchParams();
  if (branchId) {
    query.set('branch_id', branchId);
  }
  if (typeof isActive === 'boolean') {
    query.set('is_active', String(isActive));
  }
  if (typeof isPublished === 'boolean') {
    query.set('is_published', String(isPublished));
  }
  const querySuffix = query.size ? `?${query.toString()}` : '';

  const response = await httpClient<AdminPromotionResponse[]>({
    path: `${ADMIN_PROMOTIONS_BASE_PATH}${querySuffix}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return response.map(mapPromotion);
}

export async function getAdminPromotion({
  accessToken,
  promotionId,
}: AuthorizedRequest & { promotionId: string }): Promise<AdminPromotion> {
  const response = await httpClient<AdminPromotionResponse>({
    path: `${ADMIN_PROMOTIONS_BASE_PATH}/${promotionId}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return mapPromotion(response);
}

export async function createAdminPromotion({
  accessToken,
  payload,
}: AuthorizedRequest & { payload: AdminPromotionCreatePayload }): Promise<AdminPromotion> {
  const response = await httpClient<AdminPromotionResponse>({
    path: ADMIN_PROMOTIONS_BASE_PATH,
    method: 'POST',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializePromotionPayload(payload)),
  });

  return mapPromotion(response);
}

export async function updateAdminPromotion({
  accessToken,
  promotionId,
  payload,
}: AuthorizedRequest & {
  promotionId: string;
  payload: AdminPromotionUpdatePayload;
}): Promise<AdminPromotion> {
  const response = await httpClient<AdminPromotionResponse>({
    path: `${ADMIN_PROMOTIONS_BASE_PATH}/${promotionId}`,
    method: 'PATCH',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializePromotionPayload(payload)),
  });

  return mapPromotion(response);
}

function mapPromotion(response: AdminPromotionResponse): AdminPromotion {
  return {
    id: response.id,
    title: response.title,
    description: response.description,
    badgeLabel: response.badge_label,
    imageUrl: response.image_url ?? '',
    branchIds: response.branch_ids,
    ctaLabel: response.cta_label,
    displayOrder: response.display_order,
    isActive: response.is_active,
    isPublished: response.is_published,
  };
}

function serializePromotionPayload(
  payload: AdminPromotionCreatePayload | AdminPromotionUpdatePayload,
): Record<string, unknown> {
  return {
    title: payload.title,
    description: payload.description,
    badge_label: payload.badgeLabel,
    image_url: payload.imageUrl || null,
    branch_ids: payload.branchIds,
    cta_label: payload.ctaLabel,
    display_order: payload.displayOrder,
    is_active: payload.isActive,
    is_published: payload.isPublished,
  };
}
