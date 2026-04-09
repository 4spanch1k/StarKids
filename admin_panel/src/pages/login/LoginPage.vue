<template>
  <main class="login-page">
    <form class="login-card" @submit.prevent="submit">
      <div class="login-card__copy">
        <p class="login-card__eyebrow">Star Kids</p>
        <h1>Вход в админ-панель</h1>
        <p class="login-card__description">
          Откройте рабочее пространство для заявок, филиалов и контента.
        </p>
      </div>

      <label class="admin-field">
        <span class="admin-field__label">Электронная почта</span>
        <input
          v-model="email"
          type="email"
          autocomplete="email"
          class="admin-control"
          placeholder="manager@starkids.kz"
        />
      </label>

      <label class="admin-field">
        <span class="admin-field__label">Пароль</span>
        <input
          v-model="password"
          type="password"
          autocomplete="current-password"
          class="admin-control"
          placeholder="••••••••"
        />
      </label>

      <p
        v-if="formErrorMessage"
        class="admin-inline-message admin-inline-message--error"
      >
        {{ formErrorMessage }}
      </p>

      <button
        type="submit"
        class="admin-button admin-button--primary"
        :disabled="isSubmitting"
      >
        {{ isSubmitting ? 'Входим…' : 'Войти' }}
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
    localErrorMessage.value = 'Введите email и пароль.';
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
  padding: 32px;
}

.login-card {
  display: grid;
  gap: 20px;
  width: min(100%, 420px);
  padding: 32px;
  border: 1px solid var(--color-border);
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.94);
  box-shadow: var(--shadow-soft);
}

.login-card__copy {
  display: grid;
  gap: 8px;
}

.login-card__eyebrow {
  margin: 0;
  font-size: 13px;
  font-weight: 700;
  color: var(--color-accent);
}

.login-card h1 {
  margin: 0;
  font-size: 28px;
  line-height: 1.2;
}

.login-card__description {
  margin: 0;
  line-height: 1.6;
  color: var(--color-muted);
}
</style>
