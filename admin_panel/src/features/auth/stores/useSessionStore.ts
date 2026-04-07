import { computed, ref } from 'vue';
import { defineStore } from 'pinia';

import {
  fetchCurrentAdminUser,
  loginAdmin,
  refreshAdminSession,
} from '@/features/auth/api/adminAuthApi';
import {
  clearPersistedSession,
  loadPersistedSession,
  savePersistedSession,
} from '@/features/auth/lib/sessionPersistence';
import type {
  AdminAuthResponse,
  AdminCurrentUser,
} from '@/features/auth/types';
import { HttpError } from '@/shared/api/httpClient';

export const useSessionStore = defineStore('session', () => {
  const accessToken = ref('');
  const refreshToken = ref('');
  const currentUser = ref<AdminCurrentUser | null>(null);
  const isReady = ref(false);
  const isLoading = ref(false);
  const errorMessage = ref('');
  let initializePromise: Promise<void> | null = null;

  const isAuthenticated = computed(() => {
    return Boolean(accessToken.value && currentUser.value);
  });
  const operatorEmail = computed(() => currentUser.value?.email ?? '');
  const operatorName = computed(() => currentUser.value?.full_name ?? '');
  const operatorRole = computed(() => currentUser.value?.role ?? '');

  async function initialize() {
    if (isReady.value) {
      return;
    }
    if (initializePromise) {
      return initializePromise;
    }

    initializePromise = restoreSession().finally(() => {
      isReady.value = true;
      initializePromise = null;
    });

    return initializePromise;
  }

  async function signIn(email: string, password: string) {
    errorMessage.value = '';
    isLoading.value = true;

    try {
      const response = await loginAdmin({
        email: email.trim(),
        password,
      });
      applySession(response);
      isReady.value = true;
    } catch (error) {
      clearSession();
      errorMessage.value = resolveErrorMessage(error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  function signOut() {
    errorMessage.value = '';
    clearSession();
    isReady.value = true;
  }

  async function refreshSession() {
    if (!refreshToken.value) {
      clearSession();
      throw new Error('Refresh token missing.');
    }

    const response = await refreshAdminSession({
      refresh_token: refreshToken.value,
    });
    applySession(response);
    return response;
  }

  async function restoreSession() {
    const persistedSession = loadPersistedSession();
    if (!persistedSession) {
      clearSession();
      return;
    }

    accessToken.value = persistedSession.accessToken;
    refreshToken.value = persistedSession.refreshToken;
    currentUser.value = persistedSession.currentUser;
    errorMessage.value = '';

    if (accessToken.value) {
      try {
        currentUser.value = await fetchCurrentAdminUser(accessToken.value);
        persistSession();
        return;
      } catch (error) {
        if (!isUnauthorized(error) || !refreshToken.value) {
          clearSession();
          return;
        }
      }
    }

    if (refreshToken.value) {
      try {
        await refreshSession();
      } catch {
        clearSession();
      }
    }
  }

  function applySession(response: AdminAuthResponse) {
    accessToken.value = response.access_token;
    refreshToken.value = response.refresh_token;
    currentUser.value = response.user;
    persistSession();
  }

  function persistSession() {
    if (!accessToken.value || !refreshToken.value) {
      clearPersistedSession();
      return;
    }

    savePersistedSession({
      accessToken: accessToken.value,
      refreshToken: refreshToken.value,
      currentUser: currentUser.value,
    });
  }

  function clearSession() {
    accessToken.value = '';
    refreshToken.value = '';
    currentUser.value = null;
    clearPersistedSession();
  }

  function isUnauthorized(error: unknown): error is HttpError {
    return error instanceof HttpError && error.status === 401;
  }

  function resolveErrorMessage(error: unknown): string {
    if (error instanceof HttpError) {
      return error.message;
    }
    if (error instanceof Error) {
      return error.message;
    }
    return 'Request failed.';
  }

  return {
    accessToken,
    currentUser,
    errorMessage,
    initialize,
    isLoading,
    isReady,
    operatorEmail,
    operatorName,
    operatorRole,
    isAuthenticated,
    refreshSession,
    signIn,
    signOut,
  };
});
