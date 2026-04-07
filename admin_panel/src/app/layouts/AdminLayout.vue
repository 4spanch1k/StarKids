<template>
  <div class="layout">
    <AppSidebar
      :primary-items="primaryNavigationItems"
      :secondary-items="secondaryNavigationItems"
    />

    <main class="workspace">
      <header class="workspace__topbar">
        <div class="workspace__intro">
          <p class="workspace__label">Star Kids</p>
          <p class="workspace__caption">
            Панель для обработки заявок и управления контентом без лишней сложности.
          </p>
        </div>

        <div v-if="sessionStore.currentUser" class="workspace__account">
          <div class="workspace__account-copy">
            <p class="workspace__account-name">{{ sessionStore.operatorName }}</p>
            <p class="workspace__account-meta">
              {{ roleLabel }} · {{ sessionStore.operatorEmail }}
            </p>
          </div>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="handleLogout"
          >
            Выйти
          </button>
        </div>
      </header>

      <div class="workspace__content">
        <RouterView />
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { RouterView, useRouter } from 'vue-router';

import {
  primaryNavigationItems,
  secondaryNavigationItems,
} from '@/app/router/navigation';
import { useSessionStore } from '@/features/auth/stores/useSessionStore';
import AppSidebar from '@/shared/ui/AppSidebar.vue';

const router = useRouter();
const sessionStore = useSessionStore();

const roleLabels: Record<string, string> = {
  super_admin: 'Суперадмин',
  operator: 'Оператор',
  content_manager: 'Контент-менеджер',
  sales_manager: 'Менеджер продаж',
};

const roleLabel = computed(() => {
  return sessionStore.operatorRole
    ? roleLabels[sessionStore.operatorRole] ?? 'Сотрудник'
    : 'Сотрудник';
});

async function handleLogout() {
  sessionStore.signOut();
  await router.replace({ name: 'login' });
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: 272px minmax(0, 1fr);
  min-height: 100vh;
}

.workspace {
  min-width: 0;
}

.workspace__topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 28px 32px 0;
}

.workspace__intro {
  display: grid;
  gap: 6px;
}

.workspace__label {
  margin: 0;
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-muted);
}

.workspace__caption {
  margin: 0;
  color: var(--color-text);
  font-size: 14px;
  line-height: 1.6;
}

.workspace__account {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.88);
}

.workspace__account-copy {
  display: grid;
  gap: 2px;
  min-width: 0;
  padding: 0 8px;
}

.workspace__account-name,
.workspace__account-meta {
  margin: 0;
}

.workspace__account-name {
  font-size: 14px;
  font-weight: 700;
}

.workspace__account-meta {
  color: var(--color-muted);
  font-size: 13px;
}

.workspace__content {
  padding: 24px 32px 32px;
}

@media (max-width: 1100px) {
  .layout {
    grid-template-columns: 1fr;
  }

  .workspace__topbar {
    flex-direction: column;
    align-items: stretch;
  }

  .workspace__account {
    justify-content: space-between;
  }
}
</style>
