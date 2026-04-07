export type AdminRole =
  | 'super_admin'
  | 'operator'
  | 'content_manager'
  | 'sales_manager';

export type AdminCurrentUser = {
  id: string;
  email: string;
  full_name: string;
  role: AdminRole;
};

export type AdminLoginPayload = {
  email: string;
  password: string;
};

export type AdminRefreshPayload = {
  refresh_token: string;
};

export type AdminAuthResponse = {
  access_token: string;
  refresh_token: string;
  token_type: 'bearer';
  expires_in_seconds: number;
  refresh_expires_in_seconds: number;
  user: AdminCurrentUser;
};
