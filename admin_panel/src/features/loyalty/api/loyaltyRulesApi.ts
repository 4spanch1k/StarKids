import { executeAuthorizedAdminRequest, buildAdminAuthHeaders } from '@/features/auth/lib/adminRequest';
import { httpClient } from '@/shared/api/httpClient';

export type LoyaltyRule = {
  id: string;
  eventType: string;
  rewardType: 'fixed' | 'percent';
  value: string;
  isActive: boolean;
  startsAt: string | null;
  endsAt: string | null;
};

export type LoyaltySettings = {
  maxRedemptionPercent: string;
  bonusValueKzt: string;
};

export type LoyaltySettingsUpdate = {
  maxRedemptionPercent: string;
};

export async function getLoyaltySettings(): Promise<LoyaltySettings> {
  return executeAuthorizedAdminRequest((token) => httpClient<LoyaltySettings>({
    path: '/admin/loyalty/settings', method: 'GET', headers: buildAdminAuthHeaders(token),
  }));
}

export async function updateLoyaltySettings(payload: LoyaltySettingsUpdate): Promise<LoyaltySettings> {
  return executeAuthorizedAdminRequest((token) => httpClient<LoyaltySettings>({
    path: '/admin/loyalty/settings', method: 'PATCH', headers: buildAdminAuthHeaders(token), body: JSON.stringify(payload),
  }));
}

export async function listLoyaltyRules(): Promise<LoyaltyRule[]> {
  const response = await executeAuthorizedAdminRequest((token) => httpClient<{ items: LoyaltyRule[] }>({
    path: '/admin/loyalty/rules', method: 'GET', headers: buildAdminAuthHeaders(token),
  }));
  return response.items;
}

export async function createLoyaltyRule(payload: Omit<LoyaltyRule, 'id'>): Promise<LoyaltyRule> {
  return executeAuthorizedAdminRequest((token) => httpClient<LoyaltyRule>({
    path: '/admin/loyalty/rules', method: 'POST', headers: buildAdminAuthHeaders(token), body: JSON.stringify(payload),
  }));
}

export async function updateLoyaltyRule(id: string, payload: Omit<LoyaltyRule, 'id'>): Promise<LoyaltyRule> {
  return executeAuthorizedAdminRequest((token) => httpClient<LoyaltyRule>({
    path: `/admin/loyalty/rules/${id}`, method: 'PATCH', headers: buildAdminAuthHeaders(token), body: JSON.stringify(payload),
  }));
}
