const fallbackApiBaseUrl = 'http://localhost:8000/api/v1';

export const env = {
  appTitle: import.meta.env.VITE_APP_TITLE || 'Star Kids Admin',
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL || fallbackApiBaseUrl,
} as const;

