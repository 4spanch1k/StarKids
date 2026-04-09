import {
  buildAdminAuthHeaders,
} from '@/features/auth/lib/adminRequest';
import type {
  AdminBranchContacts,
  AdminBranchContactsPayload,
  AdminBranchCreatePayload,
  AdminBranchDetail,
  AdminBranchGallery,
  AdminBranchGalleryPayload,
  AdminBranchPricesRules,
  AdminBranchPricesRulesPayload,
  AdminBranchSummary,
  AdminBranchUpdatePayload,
} from '@/features/branches/model/adminBranch';
import { httpClient } from '@/shared/api/httpClient';

const ADMIN_BRANCHES_BASE_PATH = '/admin/branches';

type AuthorizedRequest = {
  accessToken: string;
};

type AdminBranchSummaryResponse = {
  id: string;
  slug: string;
  name: string;
  city: string;
  short_label: string;
  working_hours: string;
  display_order: number;
  is_active: boolean;
};

type AdminBranchDetailResponse = AdminBranchSummaryResponse & {
  address: string;
  description: string;
  phone: string;
  whatsapp_phone: string;
  map_url: string | null;
  route_label: string | null;
  parking_hint: string | null;
  arrival_hint: string | null;
  hero_image_url: string | null;
  gallery_image_urls: string[];
  facilities: string[];
};

type AdminBranchContactsResponse = {
  branch_id: string;
  address: string;
  phone: string;
  whatsapp_phone: string;
  map_url: string | null;
  route_label: string | null;
  parking_hint: string | null;
  arrival_hint: string | null;
};

type AdminBranchGalleryResponse = {
  branch_id: string;
  hero_image_url: string | null;
  gallery_image_urls: string[];
};

type AdminBranchTariffResponse = {
  id: string;
  title: string;
  price_label: string;
  description: string;
  display_order: number;
  is_active: boolean;
};

type AdminBranchRuleResponse = {
  id: string;
  text: string;
  display_order: number;
  is_active: boolean;
};

type AdminBranchPricesRulesResponse = {
  branch_id: string;
  intro_title: string;
  intro_description: string;
  birthday_note: string;
  disclaimer: string | null;
  visit_tariffs: AdminBranchTariffResponse[];
  rules: AdminBranchRuleResponse[];
};

export async function listAdminBranches({
  accessToken,
  includeInactive = true,
}: AuthorizedRequest & { includeInactive?: boolean }): Promise<AdminBranchSummary[]> {
  const query = new URLSearchParams();
  if (includeInactive) {
    query.set('include_inactive', 'true');
  }

  const querySuffix = query.size ? `?${query.toString()}` : '';
  const response = await httpClient<AdminBranchSummaryResponse[]>({
    path: `${ADMIN_BRANCHES_BASE_PATH}${querySuffix}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return response.map(mapBranchSummary);
}

export async function getAdminBranch({
  accessToken,
  branchId,
}: AuthorizedRequest & { branchId: string }): Promise<AdminBranchDetail> {
  const response = await httpClient<AdminBranchDetailResponse>({
    path: `${ADMIN_BRANCHES_BASE_PATH}/${branchId}`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return mapBranchDetail(response);
}

export async function createAdminBranch({
  accessToken,
  payload,
}: AuthorizedRequest & { payload: AdminBranchCreatePayload }): Promise<AdminBranchDetail> {
  const response = await httpClient<AdminBranchDetailResponse>({
    path: ADMIN_BRANCHES_BASE_PATH,
    method: 'POST',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializeBranchPayload(payload)),
  });

  return mapBranchDetail(response);
}

export async function updateAdminBranch({
  accessToken,
  branchId,
  payload,
}: AuthorizedRequest & {
  branchId: string;
  payload: AdminBranchUpdatePayload;
}): Promise<AdminBranchDetail> {
  const response = await httpClient<AdminBranchDetailResponse>({
    path: `${ADMIN_BRANCHES_BASE_PATH}/${branchId}`,
    method: 'PATCH',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify(serializeBranchPayload(payload)),
  });

  return mapBranchDetail(response);
}

export async function getAdminBranchContacts({
  accessToken,
  branchId,
}: AuthorizedRequest & { branchId: string }): Promise<AdminBranchContacts> {
  const response = await httpClient<AdminBranchContactsResponse>({
    path: `${ADMIN_BRANCHES_BASE_PATH}/${branchId}/contacts`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return mapBranchContacts(response);
}

export async function updateAdminBranchContacts({
  accessToken,
  branchId,
  payload,
}: AuthorizedRequest & {
  branchId: string;
  payload: AdminBranchContactsPayload;
}): Promise<AdminBranchContacts> {
  const response = await httpClient<AdminBranchContactsResponse>({
    path: `${ADMIN_BRANCHES_BASE_PATH}/${branchId}/contacts`,
    method: 'PUT',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify({
      address: payload.address,
      phone: payload.phone,
      whatsapp_phone: payload.whatsappPhone,
      map_url: payload.mapUrl,
      route_label: payload.routeLabel,
      parking_hint: payload.parkingHint || null,
      arrival_hint: payload.arrivalHint || null,
    }),
  });

  return mapBranchContacts(response);
}

export async function getAdminBranchGallery({
  accessToken,
  branchId,
}: AuthorizedRequest & { branchId: string }): Promise<AdminBranchGallery> {
  const response = await httpClient<AdminBranchGalleryResponse>({
    path: `${ADMIN_BRANCHES_BASE_PATH}/${branchId}/gallery`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return mapBranchGallery(response);
}

export async function updateAdminBranchGallery({
  accessToken,
  branchId,
  payload,
}: AuthorizedRequest & {
  branchId: string;
  payload: AdminBranchGalleryPayload;
}): Promise<AdminBranchGallery> {
  const response = await httpClient<AdminBranchGalleryResponse>({
    path: `${ADMIN_BRANCHES_BASE_PATH}/${branchId}/gallery`,
    method: 'PUT',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify({
      hero_image_url: payload.heroImageUrl || null,
      gallery_image_urls: payload.galleryImageUrls,
    }),
  });

  return mapBranchGallery(response);
}

export async function getAdminBranchPricesRules({
  accessToken,
  branchId,
}: AuthorizedRequest & { branchId: string }): Promise<AdminBranchPricesRules> {
  const response = await httpClient<AdminBranchPricesRulesResponse>({
    path: `${ADMIN_BRANCHES_BASE_PATH}/${branchId}/prices-rules`,
    method: 'GET',
    headers: buildAdminAuthHeaders(accessToken),
  });

  return mapBranchPricesRules(response);
}

export async function upsertAdminBranchPricesRules({
  accessToken,
  branchId,
  payload,
}: AuthorizedRequest & {
  branchId: string;
  payload: AdminBranchPricesRulesPayload;
}): Promise<AdminBranchPricesRules> {
  const response = await httpClient<AdminBranchPricesRulesResponse>({
    path: `${ADMIN_BRANCHES_BASE_PATH}/${branchId}/prices-rules`,
    method: 'PUT',
    headers: buildAdminAuthHeaders(accessToken),
    body: JSON.stringify({
      intro_title: payload.introTitle,
      intro_description: payload.introDescription,
      birthday_note: payload.birthdayNote,
      disclaimer: payload.disclaimer || null,
      visit_tariffs: payload.visitTariffs.map((tariff) => ({
        title: tariff.title,
        price_label: tariff.priceLabel,
        description: tariff.description,
        display_order: tariff.displayOrder,
        is_active: tariff.isActive,
      })),
      rules: payload.rules.map((rule) => ({
        text: rule.text,
        display_order: rule.displayOrder,
        is_active: rule.isActive,
      })),
    }),
  });

  return mapBranchPricesRules(response);
}

function mapBranchSummary(response: AdminBranchSummaryResponse): AdminBranchSummary {
  return {
    id: response.id,
    slug: response.slug,
    name: response.name,
    city: response.city,
    shortLabel: response.short_label,
    workingHours: response.working_hours,
    displayOrder: response.display_order,
    isActive: response.is_active,
  };
}

function mapBranchDetail(response: AdminBranchDetailResponse): AdminBranchDetail {
  return {
    ...mapBranchSummary(response),
    address: response.address,
    description: response.description,
    phone: response.phone,
    whatsappPhone: response.whatsapp_phone,
    mapUrl: response.map_url ?? '',
    routeLabel: response.route_label ?? '',
    parkingHint: response.parking_hint ?? '',
    arrivalHint: response.arrival_hint ?? '',
    heroImageUrl: response.hero_image_url ?? '',
    galleryImageUrls: response.gallery_image_urls,
    facilities: response.facilities,
  };
}

function mapBranchContacts(response: AdminBranchContactsResponse): AdminBranchContacts {
  return {
    branchId: response.branch_id,
    address: response.address,
    phone: response.phone,
    whatsappPhone: response.whatsapp_phone,
    mapUrl: response.map_url ?? '',
    routeLabel: response.route_label ?? '',
    parkingHint: response.parking_hint ?? '',
    arrivalHint: response.arrival_hint ?? '',
  };
}

function mapBranchGallery(response: AdminBranchGalleryResponse): AdminBranchGallery {
  return {
    branchId: response.branch_id,
    heroImageUrl: response.hero_image_url ?? '',
    galleryImageUrls: response.gallery_image_urls,
  };
}

function mapBranchPricesRules(
  response: AdminBranchPricesRulesResponse,
): AdminBranchPricesRules {
  return {
    branchId: response.branch_id,
    introTitle: response.intro_title,
    introDescription: response.intro_description,
    birthdayNote: response.birthday_note,
    disclaimer: response.disclaimer ?? '',
    visitTariffs: response.visit_tariffs.map((tariff) => ({
      id: tariff.id,
      title: tariff.title,
      priceLabel: tariff.price_label,
      description: tariff.description,
      displayOrder: tariff.display_order,
      isActive: tariff.is_active,
    })),
    rules: response.rules.map((rule) => ({
      id: rule.id,
      text: rule.text,
      displayOrder: rule.display_order,
      isActive: rule.is_active,
    })),
  };
}

function serializeBranchPayload(
  payload: AdminBranchCreatePayload | AdminBranchUpdatePayload,
): Record<string, unknown> {
  return {
    slug: payload.slug,
    name: payload.name,
    city: payload.city,
    address: payload.address,
    short_label: payload.shortLabel,
    working_hours: payload.workingHours,
    description: payload.description,
    phone: payload.phone,
    whatsapp_phone: payload.whatsappPhone,
    map_url: payload.mapUrl || null,
    route_label: payload.routeLabel || null,
    parking_hint: payload.parkingHint || null,
    arrival_hint: payload.arrivalHint || null,
    hero_image_url: payload.heroImageUrl || null,
    gallery_image_urls: payload.galleryImageUrls,
    facilities: payload.facilities,
    display_order: payload.displayOrder,
    is_active: payload.isActive,
  };
}
