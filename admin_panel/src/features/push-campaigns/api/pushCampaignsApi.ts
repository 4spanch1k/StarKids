import { executeAuthorizedAdminRequest, buildAdminAuthHeaders } from '@/features/auth/lib/adminRequest';
import { httpClient } from '@/shared/api/httpClient';

export type VisitAudienceSegment = 'never_visited' | 'first_visit_only' | 'returning' | 'dormant_30' | 'dormant_60' | 'dormant_90';
export type CampaignAudience =
  | { type: 'all_users' }
  | { type: 'birthday_in_days'; days_before_birthday: number }
  | { type: 'user'; user_id: string }
  | { type: 'visit_segment'; visit_segment: VisitAudienceSegment };
export type PushCampaign = {
  id: string; internal_name: string; title: string; body: string; audience: CampaignAudience;
  destination: 'home' | 'tickets' | 'birthdays' | 'promotions' | 'profile'; origin: 'manual' | 'system_birthday' | 'system_first_to_second_visit' | 'system_reactivation'; status: string;
  scheduled_at: string | null; started_at: string | null; sent_at: string | null; cancelled_at: string | null;
  targeted_users: number; targeted_devices: number; sent_count: number; failed_count: number;
  failure_reason: string | null; opened_count: number;
  push_provider_configured: boolean;
};
export type PushCampaignAttribution = {
  campaign_id: string;
  targeted_users: number;
  sent_users: number;
  opened_users: number;
  open_rate: number | null;
  attributed_visit_users: number;
  attributed_visits: number;
  attributed_birthday_lead_users: number;
  attributed_birthday_leads: number;
  attribution_window_days: number;
  attribution_model: 'last_touch';
};
export type FirstSecondVisitReport = {
  journey_key: string;
  eligible_families: number;
  control_size: number;
  treatment_size: number;
  treatment_delivered: number;
  treatment_opened: number;
  control_conversions: number;
  treatment_conversions: number;
  control_second_visit_rate: number | null;
  treatment_second_visit_rate: number | null;
  absolute_uplift_percentage_points: number | null;
};
export type BirthdayRevenueReport = {
  eligible_cycles: number; control_cycles: number; treatment_cycles: number;
  windows: Record<string, { campaigns: number; delivered: number; opened: number }>;
  control: Record<string, number | null>; treatment: Record<string, number | null>;
  lost_reasons: Record<string, number>; absolute_uplift_percentage_points: number | null;
  revenue_per_eligible_difference: number;
};
export type ReactivationReport = {
  journey_key: string; eligible_families: number; control_size: number; treatment_size: number;
  treatment_delivered: number; treatment_opened: number; control_conversions: number; treatment_conversions: number;
  control_reactivation_rate: number | null; treatment_reactivation_rate: number | null;
  absolute_uplift_percentage_points: number | null;
};
export type CampaignInput = { internal_name: string; title: string; body: string; audience: CampaignAudience; destination: PushCampaign['destination']; scheduled_at?: string | null; send_now?: boolean; idempotency_key?: string };

export function listPushCampaigns() { return executeAuthorizedAdminRequest((token) => httpClient<PushCampaign[]>({ path: '/api/v1/admin/push-campaigns', headers: buildAdminAuthHeaders(token) })); }
export function createPushCampaign(input: CampaignInput) { return executeAuthorizedAdminRequest((token) => httpClient<PushCampaign>({ path: '/api/v1/admin/push-campaigns', method: 'POST', headers: buildAdminAuthHeaders(token), body: JSON.stringify(input) })); }
export function sendPushCampaign(id: string) { return executeAuthorizedAdminRequest((token) => httpClient<PushCampaign>({ path: `/api/v1/admin/push-campaigns/${id}/send`, method: 'POST', headers: buildAdminAuthHeaders(token) })); }
export function cancelPushCampaign(id: string) { return executeAuthorizedAdminRequest((token) => httpClient<PushCampaign>({ path: `/api/v1/admin/push-campaigns/${id}/cancel`, method: 'POST', headers: buildAdminAuthHeaders(token) })); }
export function previewPushAudience(audience: CampaignAudience) { return executeAuthorizedAdminRequest((token) => httpClient<{ targeted_users: number; targeted_devices: number }>({ path: '/api/v1/admin/push-campaigns/audience-preview', method: 'POST', headers: buildAdminAuthHeaders(token), body: JSON.stringify({ audience }) })); }
export function fetchPushCampaignAttribution(id: string) { return executeAuthorizedAdminRequest((token) => httpClient<PushCampaignAttribution>({ path: `/api/v1/admin/push-campaigns/${id}/attribution`, headers: buildAdminAuthHeaders(token) })); }
export function fetchFirstSecondVisitReport() { return executeAuthorizedAdminRequest((token) => httpClient<FirstSecondVisitReport>({ path: '/api/v1/admin/push-campaigns/first-to-second-visit/report', headers: buildAdminAuthHeaders(token) })); }
export function fetchBirthdayRevenueReport() { return executeAuthorizedAdminRequest((token) => httpClient<BirthdayRevenueReport>({ path: '/api/v1/admin/push-campaigns/birthday-revenue/report', headers: buildAdminAuthHeaders(token) })); }
export function fetchReactivationReport() { return executeAuthorizedAdminRequest((token) => httpClient<ReactivationReport>({ path: '/api/v1/admin/push-campaigns/reactivation/report', headers: buildAdminAuthHeaders(token) })); }
