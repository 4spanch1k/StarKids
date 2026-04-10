<template>
  <div class="layout">
    <div
      v-if="isSidebarOpen"
      class="layout__overlay"
      @click="closeSidebar"
    ></div>

    <AppSidebar
      class="layout__sidebar"
      :class="{ 'sidebar--open': isSidebarOpen }"
      :primary-items="primaryNavigationItems"
      :secondary-items="secondaryNavigationItems"
      @navigate="closeSidebar"
    />

    <main class="workspace">
      <header class="workspace__topbar">
        <div class="workspace__topbar-leading">
          <button
            type="button"
            class="workspace__menu-button"
            @click="toggleSidebar"
          >
            <span aria-hidden="true">☰</span>
            <span class="workspace__menu-text">Меню</span>
          </button>

          <div class="workspace__intro">
            <p class="workspace__label">Star Kids</p>
            <p class="workspace__caption">
              Панель для обработки заявок и управления контентом без лишней сложности.
            </p>
          </div>
        </div>

        <details v-if="sessionStore.currentUser" class="workspace__account-menu">
          <summary class="workspace__account-trigger">
            <div class="workspace__account-copy">
              <p class="workspace__account-name">{{ sessionStore.operatorName }}</p>
              <p class="workspace__account-meta">
                {{ roleLabel }} · {{ sessionStore.operatorEmail }}
              </p>
            </div>
            <span class="workspace__account-chevron" aria-hidden="true">▾</span>
          </summary>

          <div class="workspace__account-popover">
            <button
              type="button"
              class="workspace__account-action"
              @click="handleLogout"
            >
              Выйти из панели
            </button>
          </div>
        </details>
      </header>

      <div class="workspace__content">
        <RouterView />
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { RouterView, useRouter } from 'vue-router';

import {
  primaryNavigationItems,
  secondaryNavigationItems,
} from '@/app/router/navigation';
import { useSessionStore } from '@/features/auth/stores/useSessionStore';
import AppSidebar from '@/shared/ui/AppSidebar.vue';

const router = useRouter();
const sessionStore = useSessionStore();
const isSidebarOpen = ref(false);

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
  closeSidebar();
  sessionStore.signOut();
  await router.replace({ name: 'login' });
}

function toggleSidebar() {
  isSidebarOpen.value = !isSidebarOpen.value;
}

function closeSidebar() {
  isSidebarOpen.value = false;
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: 248px minmax(0, 1fr);
  min-height: 100vh;
}

.layout__overlay {
  display: none;
}

.workspace {
  min-width: 0;
}

.workspace__topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 20px 24px 0;
}

.workspace__topbar-leading {
  display: flex;
  align-items: center;
  gap: 12px;
}

.workspace__menu-button {
  display: none;
  align-items: center;
  gap: 8px;
  min-height: 38px;
  padding: 0 12px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  color: var(--color-text);
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
}

.workspace__intro {
  display: grid;
  gap: 4px;
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
  font-size: 13px;
  line-height: 1.5;
}

.workspace__account-menu {
  position: relative;
  min-width: 0;
}

.workspace__account-menu[open] .workspace__account-trigger {
  border-color: var(--color-border-strong);
  box-shadow: var(--shadow-soft);
}

.workspace__account-trigger {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 280px;
  padding: 8px 10px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.92);
  cursor: pointer;
  list-style: none;
}

.workspace__account-trigger::-webkit-details-marker {
  display: none;
}

.workspace__account-copy {
  display: grid;
  gap: 2px;
  min-width: 0;
  flex: 1;
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

.workspace__account-chevron {
  color: var(--color-muted);
  font-size: 12px;
}

.workspace__account-popover {
  position: absolute;
  right: 0;
  z-index: 10;
  display: grid;
  gap: 8px;
  min-width: 220px;
  margin-top: 8px;
  padding: 8px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  box-shadow: var(--shadow-soft);
}

.workspace__account-action {
  min-height: 38px;
  padding: 0 12px;
  border: 0;
  border-radius: 12px;
  background: var(--color-surface-subtle);
  color: var(--color-text);
  font-size: 14px;
  font-weight: 600;
  text-align: left;
  cursor: pointer;
}

.workspace__account-action:hover {
  background: var(--color-surface-muted);
}

.workspace__content {
  padding: 18px 24px 24px;
}

@media (max-width: 1100px) {
  .layout {
    grid-template-columns: 1fr;
  }

  .layout__overlay {
    position: fixed;
    inset: 0;
    z-index: 30;
    display: block;
    background: rgba(15, 23, 42, 0.24);
  }

  .workspace__topbar {
    padding: 12px 16px 0;
  }

  .workspace__menu-button {
    display: inline-flex;
  }

  .workspace__menu-text,
  .workspace__caption,
  .workspace__account-meta {
    display: none;
  }

  .workspace__account-trigger {
    min-width: 0;
    width: auto;
    padding: 8px 10px;
  }

  .workspace__account-name {
    font-size: 13px;
  }

  .workspace__content {
    padding: 12px 16px 20px;
  }
}

@media (max-width: 720px) {
  .workspace__label {
    font-size: 12px;
  }
}
</style>
