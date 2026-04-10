import { useSessionStore } from '@/features/auth/stores/useSessionStore';
import { HttpError } from '@/shared/api/httpClient';

export async function executeAuthorizedAdminRequest<T>(
  request: (accessToken: string) => Promise<T>,
): Promise<T> {
  const sessionStore = useSessionStore();

  try {
    return await request(sessionStore.accessToken);
  } catch (error) {
    if (!(error instanceof HttpError) || error.status !== 401) {
      throw error;
    }

    await sessionStore.refreshSession();
    return request(sessionStore.accessToken);
  }
}

export function buildAdminAuthHeaders(accessToken: string): HeadersInit {
  return {
    Authorization: `Bearer ${accessToken}`,
  };
}

export function resolveAdminRequestError(
  error: unknown,
  fallbackMessage: string,
): string {
  if (error instanceof HttpError) {
    return error.message;
  }

  if (error instanceof Error && error.message) {
    return error.message;
  }

  return fallbackMessage;
}
