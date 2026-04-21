import { buildAdminAuthHeaders } from '@/features/auth/lib/adminRequest';
import type {
  AdminNews,
  AdminNewsCreatePayload,
  AdminNewsUpdatePayload,
} from '@/features/news/model/adminNews';
import { httpClient } from '@/shared/api/httpClient';

const ADMIN_NEWS_BASE_PATH = '/admin/news';

type AuthorizedRequest = {
  accessToken: string;
};

type AdminNewsResponse = {
  id: string;
  title: string;
  image_url: string;
  description: string | null;
  is_active: boolean;
  display_order: number;
  publish_at: string | null;
  created_at: string;
};

type AdminNewsImageUploadResponse = {
  image_url: string;
};

export async function listAdminNews({
  accessToken,
}: AuthorizedRequest): Promise<AdminNews[]> {
  const response = await httpClient<AdminNewsResponse[]>({
    path: ADMIN_NEWS_BASE_PATH,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return response.map(mapNews);
}

export async function getAdminNews({
  accessToken,
  newsId,
}: AuthorizedRequest & {
  newsId: string;
}): Promise<AdminNews> {
  const response = await httpClient<AdminNewsResponse>({
    path: `${ADMIN_NEWS_BASE_PATH}/${newsId}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return mapNews(response);
}

export async function createAdminNews({
  accessToken,
  payload,
}: AuthorizedRequest & {
  payload: AdminNewsCreatePayload;
}): Promise<AdminNews> {
  const response = await httpClient<AdminNewsResponse>({
    path: ADMIN_NEWS_BASE_PATH,
    method: 'POST',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializeNewsPayload(payload)),
  });

  return mapNews(response);
}

export async function updateAdminNews({
  accessToken,
  newsId,
  payload,
}: AuthorizedRequest & {
  newsId: string;
  payload: AdminNewsUpdatePayload;
}): Promise<AdminNews> {
  const response = await httpClient<AdminNewsResponse>({
    path: `${ADMIN_NEWS_BASE_PATH}/${newsId}`,
    method: 'PATCH',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializeNewsPayload(payload)),
  });

  return mapNews(response);
}

export async function deleteAdminNews({
  accessToken,
  newsId,
}: AuthorizedRequest & {
  newsId: string;
}): Promise<void> {
  await httpClient<null>({
    path: `${ADMIN_NEWS_BASE_PATH}/${newsId}`,
    method: 'DELETE',
    headers: buildAdminAuthHeaders(accessToken),
  });
}

export async function uploadAdminNewsImage({
  accessToken,
  file,
}: AuthorizedRequest & {
  file: File;
}): Promise<{ imageUrl: string }> {
  const formData = new FormData();
  formData.append('file', file);

  const response = await httpClient<AdminNewsImageUploadResponse>({
    path: `${ADMIN_NEWS_BASE_PATH}/upload-image`,
    method: 'POST',
    headers: buildAdminAuthHeaders(accessToken),
    body: formData,
  });

  return {
    imageUrl: response.image_url,
  };
}

function mapNews(response: AdminNewsResponse): AdminNews {
  return {
    id: response.id,
    title: response.title,
    imageUrl: response.image_url,
    description: response.description ?? '',
    isActive: response.is_active,
    displayOrder: response.display_order ?? 0,
    publishAt: response.publish_at,
    createdAt: response.created_at,
  };
}

function serializeNewsPayload(
  payload: AdminNewsCreatePayload | AdminNewsUpdatePayload,
): Record<string, unknown> {
  return {
    title: payload.title,
    image_url: payload.imageUrl,
    description: payload.description?.trim() ? payload.description.trim() : null,
    is_active: payload.isActive,
    display_order: payload.displayOrder ?? 0,
    publish_at: serializePublishAt(payload.publishAt),
  };
}

function serializePublishAt(value: string | null | undefined): string | null {
  const normalized = value?.trim();
  if (!normalized) {
    return null;
  }

  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) {
    return normalized;
  }

  return parsed.toISOString();
}
