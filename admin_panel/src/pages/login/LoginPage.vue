<template>
  <main class="login-page">
    <form class="login-card" @submit.prevent="submit">
      <div>
        <p class="eyebrow">Admin access</p>
        <h1>Star Kids Admin</h1>
        <p class="description">
          Foundation login screen for operators, content managers, and sales managers.
        </p>
      </div>

      <label class="field">
        <span>Email</span>
        <input
          v-model="email"
          type="email"
          autocomplete="email"
          placeholder="manager@starkids.kz"
        />
      </label>

      <label class="field">
        <span>Password</span>
        <input
          v-model="password"
          type="password"
          autocomplete="current-password"
          placeholder="••••••••"
        />
      </label>

      <p v-if="formErrorMessage" class="error-message">{{ formErrorMessage }}</p>

      <button type="submit" :disabled="isSubmitting">
        {{ isSubmitting ? 'Signing in...' : 'Continue' }}
      </button>
    </form>
  </main>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { useSessionStore } from '@/features/auth/stores/useSessionStore';

const router = useRouter();
const route = useRoute();
const sessionStore = useSessionStore();

const email = ref('');
const password = ref('');
const localErrorMessage = ref('');
const isSubmitting = computed(() => sessionStore.isLoading);
const formErrorMessage = computed(() => {
  return localErrorMessage.value || sessionStore.errorMessage;
});

async function submit() {
  localErrorMessage.value = '';

  if (!email.value || !password.value) {
    localErrorMessage.value = 'Enter email and password.';
    return;
  }

  try {
    await sessionStore.signIn(email.value, password.value);
    const redirectPath =
      typeof route.query.redirect === 'string' ? route.query.redirect : '/';
    await router.replace(redirectPath);
  } catch {
    // Error state is already reflected by the auth store.
  }
}
</script>

<style scoped>
.login-page {
  display: grid;
  place-items: center;
  min-height: 100vh;
  padding: 24px;
}

.login-card {
  display: grid;
  gap: 18px;
  width: min(100%, 440px);
  padding: 28px;
  border: 1px solid var(--color-border);
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.88);
  box-shadow: var(--shadow-soft);
}

.eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-accent);
}

h1 {
  margin: 0 0 8px;
}

.description {
  margin: 0;
  line-height: 1.6;
  color: var(--color-muted);
}

.field {
  display: grid;
  gap: 8px;
}

.field input {
  border: 1px solid var(--color-border);
  border-radius: 14px;
  padding: 12px 14px;
  background: #fff;
}

.error-message {
  margin: 0;
  color: #c53d3d;
}

button {
  border: none;
  border-radius: 14px;
  padding: 14px 16px;
  background: var(--color-accent);
  color: #fff;
  cursor: pointer;
}

button:disabled {
  opacity: 0.72;
  cursor: wait;
}
</style>
