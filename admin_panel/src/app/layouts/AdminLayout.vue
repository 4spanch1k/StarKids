<template>
  <div class="layout">
    <AppSidebar :items="navigationItems" />
    <main class="content">
      <header class="topbar">
        <div>
          <p class="eyebrow">Star Kids Admin</p>
          <h1>{{ currentLabel }}</h1>
        </div>
        <div v-if="sessionStore.currentUser" class="account-panel">
          <div class="account-copy">
            <p class="account-name">{{ sessionStore.operatorName }}</p>
            <p class="account-meta">
              {{ sessionStore.operatorEmail }} · {{ roleLabel }}
            </p>
          </div>
          <button type="button" class="logout-button" @click="handleLogout">
            Log out
          </button>
        </div>
      </header>
      <div class="page-content">
        <RouterView />
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { RouterView, useRoute, useRouter } from 'vue-router';

import { navigationItems } from '@/app/router/navigation';
import { useSessionStore } from '@/features/auth/stores/useSessionStore';
import AppSidebar from '@/shared/ui/AppSidebar.vue';

const route = useRoute();
const router = useRouter();
const sessionStore = useSessionStore();

const currentLabel = computed(() => {
  return navigationItems.find((item) => item.name === route.name)?.label ?? 'Admin';
});

const roleLabel = computed(() => {
  if (!sessionStore.operatorRole) {
    return 'Admin';
  }

  return sessionStore.operatorRole
    .split('_')
    .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
    .join(' ');
});

async function handleLogout() {
  sessionStore.signOut();
  await router.replace({ name: 'login' });
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: 280px 1fr;
  min-height: 100vh;
}

.content {
  min-width: 0;
}

.topbar {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding: 24px 32px 0;
}

.eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-accent);
}

.topbar h1 {
  margin: 0;
  font-size: 28px;
  line-height: 1.2;
}

.page-content {
  padding: 24px 32px 32px;
}

.account-panel {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 12px 14px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.88);
  box-shadow: var(--shadow-soft);
}

.account-copy {
  min-width: 0;
}

.account-name,
.account-meta {
  margin: 0;
}

.account-name {
  font-weight: 700;
}

.account-meta {
  color: var(--color-muted);
}

.logout-button {
  border: 1px solid var(--color-border);
  border-radius: 12px;
  padding: 10px 12px;
  background: #fff;
  cursor: pointer;
}

@media (max-width: 1024px) {
  .layout {
    grid-template-columns: 1fr;
  }

  .topbar {
    flex-direction: column;
  }
}
</style>
