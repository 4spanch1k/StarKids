import { buildAdminAuthHeaders } from '@/features/auth/lib/adminRequest';
import type {
  AdminContentBlock,
  AdminContentBlockCreatePayload,
  AdminContentBlockUpdatePayload,
  AdminFaq,
  AdminFaqCreatePayload,
  AdminFaqUpdatePayload,
} from '@/features/content/model/adminContent';
import { httpClient } from '@/shared/api/httpClient';

const ADMIN_FAQS_BASE_PATH = '/admin/faqs';
const ADMIN_CONTENT_BLOCKS_BASE_PATH = '/admin/content-blocks';

type AuthorizedRequest = {
  accessToken: string;
};

type AdminFaqResponse = {
  id: string;
  question: string;
  answer: string;
  display_order: number;
  is_active: boolean;
  is_published: boolean;
};

type AdminContentBlockResponse = {
  id: string;
  surface: string;
  key: string;
  title: string;
  body: string;
  cta_label: string | null;
  display_order: number;
  is_active: boolean;
  is_published: boolean;
};

export async function listAdminFaqs({
  accessToken,
  isActive,
  isPublished,
}: AuthorizedRequest & {
  isActive?: boolean | '';
  isPublished?: boolean | '';
}): Promise<AdminFaq[]> {
  const query = new URLSearchParams();
  if (typeof isActive === 'boolean') {
    query.set('is_active', String(isActive));
  }
  if (typeof isPublished === 'boolean') {
    query.set('is_published', String(isPublished));
  }
  const querySuffix = query.size ? `?${query.toString()}` : '';

  const response = await httpClient<AdminFaqResponse[]>({
    path: `${ADMIN_FAQS_BASE_PATH}${querySuffix}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return response.map(mapFaq);
}

export async function getAdminFaq({
  accessToken,
  faqId,
}: AuthorizedRequest & { faqId: string }): Promise<AdminFaq> {
  const response = await httpClient<AdminFaqResponse>({
    path: `${ADMIN_FAQS_BASE_PATH}/${faqId}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return mapFaq(response);
}

export async function createAdminFaq({
  accessToken,
  payload,
}: AuthorizedRequest & { payload: AdminFaqCreatePayload }): Promise<AdminFaq> {
  const response = await httpClient<AdminFaqResponse>({
    path: ADMIN_FAQS_BASE_PATH,
    method: 'POST',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializeFaqPayload(payload)),
  });

  return mapFaq(response);
}

export async function updateAdminFaq({
  accessToken,
  faqId,
  payload,
}: AuthorizedRequest & { faqId: string; payload: AdminFaqUpdatePayload }): Promise<AdminFaq> {
  const response = await httpClient<AdminFaqResponse>({
    path: `${ADMIN_FAQS_BASE_PATH}/${faqId}`,
    method: 'PATCH',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializeFaqPayload(payload)),
  });

  return mapFaq(response);
}

export async function listAdminContentBlocks({
  accessToken,
  surface,
  isActive,
  isPublished,
}: AuthorizedRequest & {
  surface?: string;
  isActive?: boolean | '';
  isPublished?: boolean | '';
}): Promise<AdminContentBlock[]> {
  const query = new URLSearchParams();
  if (surface) {
    query.set('surface', surface);
  }
  if (typeof isActive === 'boolean') {
    query.set('is_active', String(isActive));
  }
  if (typeof isPublished === 'boolean') {
    query.set('is_published', String(isPublished));
  }
  const querySuffix = query.size ? `?${query.toString()}` : '';

  const response = await httpClient<AdminContentBlockResponse[]>({
    path: `${ADMIN_CONTENT_BLOCKS_BASE_PATH}${querySuffix}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return response.map(mapContentBlock);
}

export async function getAdminContentBlock({
  accessToken,
  blockId,
}: AuthorizedRequest & { blockId: string }): Promise<AdminContentBlock> {
  const response = await httpClient<AdminContentBlockResponse>({
    path: `${ADMIN_CONTENT_BLOCKS_BASE_PATH}/${blockId}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return mapContentBlock(response);
}

export async function createAdminContentBlock({
  accessToken,
  payload,
}: AuthorizedRequest & {
  payload: AdminContentBlockCreatePayload;
}): Promise<AdminContentBlock> {
  const response = await httpClient<AdminContentBlockResponse>({
    path: ADMIN_CONTENT_BLOCKS_BASE_PATH,
    method: 'POST',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializeContentBlockPayload(payload)),
  });

  return mapContentBlock(response);
}

export async function updateAdminContentBlock({
  accessToken,
  blockId,
  payload,
}: AuthorizedRequest & {
  blockId: string;
  payload: AdminContentBlockUpdatePayload;
}): Promise<AdminContentBlock> {
  const response = await httpClient<AdminContentBlockResponse>({
    path: `${ADMIN_CONTENT_BLOCKS_BASE_PATH}/${blockId}`,
    method: 'PATCH',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializeContentBlockPayload(payload)),
  });

  return mapContentBlock(response);
}

function mapFaq(response: AdminFaqResponse): AdminFaq {
  return {
    id: response.id,
    question: response.question,
    answer: response.answer,
    displayOrder: response.display_order,
    isActive: response.is_active,
    isPublished: response.is_published,
  };
}

function serializeFaqPayload(
  payload: AdminFaqCreatePayload | AdminFaqUpdatePayload,
): Record<string, unknown> {
  return {
    question: payload.question,
    answer: payload.answer,
    display_order: payload.displayOrder,
    is_active: payload.isActive,
    is_published: payload.isPublished,
  };
}

function mapContentBlock(response: AdminContentBlockResponse): AdminContentBlock {
  return {
    id: response.id,
    surface: response.surface,
    key: response.key,
    title: response.title,
    body: response.body,
    ctaLabel: response.cta_label ?? '',
    displayOrder: response.display_order,
    isActive: response.is_active,
    isPublished: response.is_published,
  };
}

function serializeContentBlockPayload(
  payload: AdminContentBlockCreatePayload | AdminContentBlockUpdatePayload,
): Record<string, unknown> {
  return {
    surface: payload.surface,
    key: payload.key,
    title: payload.title,
    body: payload.body,
    cta_label: payload.ctaLabel || null,
    display_order: payload.displayOrder,
    is_active: payload.isActive,
    is_published: payload.isPublished,
  };
}
