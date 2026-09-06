import { executeAuthorizedAdminRequest, buildAdminAuthHeaders } from '@/features/auth/lib/adminRequest';
import { httpClient } from '@/shared/api/httpClient';

export type CampaignAudience = { type: 'all_users' | 'birthday_in_days'; days_before_birthday?: number };
export type PushCampaign = {
  id: string; internal_name: string; title: string; body: string; audience: CampaignAudience;
  destination: 'home' | 'tickets' | 'birthdays' | 'promotions' | 'profile'; status: string;
  scheduled_at: string | null; targeted_users: number; targeted_devices: number; sent_count: number; failed_count: number;
  push_provider_configured: boolean;
};
export type CampaignInput = { internal_name: string; title: string; body: string; audience: CampaignAudience; destination: PushCampaign['destination']; scheduled_at?: string | null };

export function listPushCampaigns() { return executeAuthorizedAdminRequest((token) => httpClient<PushCampaign[]>({ path: '/api/v1/admin/push-campaigns', headers: buildAdminAuthHeaders(token) })); }
export function createPushCampaign(input: CampaignInput) { return executeAuthorizedAdminRequest((token) => httpClient<PushCampaign>({ path: '/api/v1/admin/push-campaigns', method: 'POST', headers: buildAdminAuthHeaders(token), body: JSON.stringify(input) })); }
export function sendPushCampaign(id: string) { return executeAuthorizedAdminRequest((token) => httpClient<PushCampaign>({ path: `/api/v1/admin/push-campaigns/${id}/send`, method: 'POST', headers: buildAdminAuthHeaders(token) })); }
export function cancelPushCampaign(id: string) { return executeAuthorizedAdminRequest((token) => httpClient<PushCampaign>({ path: `/api/v1/admin/push-campaigns/${id}/cancel`, method: 'POST', headers: buildAdminAuthHeaders(token) })); }
export function previewPushAudience(audience: CampaignAudience) { return executeAuthorizedAdminRequest((token) => httpClient<{ targeted_users: number; targeted_devices: number }>({ path: '/api/v1/admin/push-campaigns/audience-preview', method: 'POST', headers: buildAdminAuthHeaders(token), body: JSON.stringify({ audience }) })); }
