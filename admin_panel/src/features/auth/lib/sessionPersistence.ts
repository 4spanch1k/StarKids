import type { AdminCurrentUser } from '@/features/auth/types';

const STORAGE_KEY = 'star-kids.admin.session';

export type PersistedAdminSession = {
  accessToken: string;
  refreshToken: string;
  currentUser: AdminCurrentUser | null;
};

export function loadPersistedSession(): PersistedAdminSession | null {
  if (typeof window === 'undefined') {
    return null;
  }

  const rawValue = window.localStorage.getItem(STORAGE_KEY);
  if (!rawValue) {
    return null;
  }

  try {
    const parsed = JSON.parse(rawValue) as Partial<PersistedAdminSession>;
    if (
      typeof parsed.accessToken !== 'string' ||
      typeof parsed.refreshToken !== 'string'
    ) {
      return null;
    }

    return {
      accessToken: parsed.accessToken,
      refreshToken: parsed.refreshToken,
      currentUser: parsed.currentUser ?? null,
    };
  } catch {
    return null;
  }
}

export function savePersistedSession(session: PersistedAdminSession): void {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
}

export function clearPersistedSession(): void {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.removeItem(STORAGE_KEY);
}
