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
        <input v-model="email" type="email" placeholder="manager@starkids.kz" />
      </label>

      <label class="field">
        <span>Password</span>
        <input v-model="password" type="password" placeholder="••••••••" />
      </label>

      <button type="submit">Continue</button>
    </form>
  </main>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';

import { useSessionStore } from '@/features/auth/stores/useSessionStore';

const router = useRouter();
const sessionStore = useSessionStore();

const email = ref('');
const password = ref('');

function submit() {
  if (!email.value || !password.value) {
    return;
  }

  sessionStore.signIn(email.value);
  router.push('/');
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

button {
  border: none;
  border-radius: 14px;
  padding: 14px 16px;
  background: var(--color-accent);
  color: #fff;
  cursor: pointer;
}
</style>

