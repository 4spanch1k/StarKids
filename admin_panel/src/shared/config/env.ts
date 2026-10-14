const fallbackApiBaseUrl = 'http://localhost:8000/api/v1';
const configuredApiBaseUrl = (import.meta.env.VITE_API_BASE_URL || '').trim();

function resolveApiBaseUrl(): string {
  if (import.meta.env.PROD) {
    let parsed: URL;
    try {
      parsed = new URL(configuredApiBaseUrl);
    } catch {
      throw new Error('VITE_API_BASE_URL must be an explicit HTTPS URL in production.');
    }

    if (
      parsed.protocol !== 'https:' ||
      !parsed.hostname ||
      parsed.hostname === 'localhost' ||
      parsed.hostname === '127.0.0.1' ||
      parsed.hostname.endsWith('.invalid')
    ) {
      throw new Error(
        'VITE_API_BASE_URL cannot point to localhost or a placeholder host in production.',
      );
    }

    return configuredApiBaseUrl;
  }

  return configuredApiBaseUrl || fallbackApiBaseUrl;
}

export const env = {
  appTitle: import.meta.env.VITE_APP_TITLE || 'Boom Bala — админ-панель',
  apiBaseUrl: resolveApiBaseUrl(),
} as const;
