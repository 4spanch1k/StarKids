<template>
  <aside class="sidebar">
    <div class="sidebar__brand">
      <div class="sidebar__logo">SK</div>
      <div class="sidebar__copy">
        <p class="sidebar__eyebrow">Star Kids</p>
        <h2>Операционная панель</h2>
      </div>
    </div>

    <div class="sidebar__group">
      <p class="sidebar__group-title">Основное</p>
      <nav class="sidebar__nav">
        <RouterLink
          v-for="item in primaryItems"
          :key="item.name"
          :to="item.to"
          class="sidebar__link"
          active-class="sidebar__link--active"
        >
          <span class="sidebar__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
              <path :d="resolveIconPath(item.name)" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </span>
          <span class="sidebar__label">{{ item.label }}</span>
        </RouterLink>
      </nav>
    </div>

    <div v-if="secondaryItems.length" class="sidebar__group sidebar__group--secondary">
      <p class="sidebar__group-title">Дополнительно</p>
      <nav class="sidebar__nav">
        <RouterLink
          v-for="item in secondaryItems"
          :key="item.name"
          :to="item.to"
          class="sidebar__link sidebar__link--secondary"
          active-class="sidebar__link--active"
        >
          <span class="sidebar__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
              <path :d="resolveIconPath(item.name)" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </span>
          <span class="sidebar__label">{{ item.label }}</span>
        </RouterLink>
      </nav>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { RouterLink } from 'vue-router';

import type { NavigationItem } from '@/app/router/navigation';

const iconPaths: Record<string, string> = {
  leads: 'M4 6h16M4 12h10M4 18h16M18 10l2 2 4-4',
  branches: 'M4 10.5 12 4l8 6.5V20H4z',
  'birthday-packages': 'M12 4v4M8 8h8M7 12h10v8H7zM9 12c0-1.7 1.3-3 3-3s3 1.3 3 3',
  promotions: 'M7 7h10l-2 10H9L7 7zm4-3 1 3m4 9-4 4m-4-4 4 4',
  content: 'M6 7h12M6 12h12M6 17h8',
  gallery: 'M5 6h14v12H5zM8 14l2-2 2 2 3-3 2 3',
  faq: 'M9.5 9a2.5 2.5 0 1 1 4.2 1.8c-.9.8-1.7 1.3-1.7 2.7M12 18h.01',
  dashboard: 'M5 13h5V5H5zm9 6h5V5h-5zm-9 0h5v-4H5z',
  tariffs: 'M6 6h12M6 12h8M6 18h10M18 10v8m0 0-2-2m2 2 2-2',
  customers: 'M12 12a3 3 0 1 0-3-3 3 3 0 0 0 3 3Zm-6 8a6 6 0 0 1 12 0',
  'push-campaigns': 'M6 17h12l-1-7 2-2H5l2 2-1 7Zm4 3h4',
  'audit-logs': 'M7 5h10v14H7zM9 9h6M9 13h6',
};

withDefaults(
  defineProps<{
    primaryItems: NavigationItem[];
    secondaryItems?: NavigationItem[];
  }>(),
  {
    secondaryItems: () => [],
  },
);

function resolveIconPath(name: string) {
  return iconPaths[name] ?? 'M6 12h12';
}
</script>

<style scoped>
.sidebar {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  gap: 20px;
  height: 100vh;
  padding: 22px 16px;
  border-right: 1px solid var(--color-border);
  background: linear-gradient(180deg, #f7f8fb 0%, #f3f5f8 100%);
  box-shadow: var(--shadow-sidebar);
}

.sidebar__brand {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 4px 4px 2px;
}

.sidebar__logo {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: var(--color-text);
  color: #fff;
  font-size: 14px;
  font-weight: 700;
}

.sidebar__copy {
  min-width: 0;
}

.sidebar__eyebrow {
  margin: 0 0 2px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-muted);
}

.sidebar__copy h2 {
  margin: 0;
  font-size: 17px;
  line-height: 1.25;
}

.sidebar__group {
  display: grid;
  gap: 10px;
}

.sidebar__group--secondary {
  margin-top: auto;
}

.sidebar__group-title {
  margin: 0;
  padding-left: 10px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-muted);
}

.sidebar__nav {
  display: grid;
  gap: 4px;
}

.sidebar__link {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 40px;
  padding: 0 12px;
  border: 1px solid transparent;
  border-radius: 12px;
  color: var(--color-text);
  font-size: 14px;
  font-weight: 600;
  transition:
    background-color 120ms ease,
    border-color 120ms ease,
    color 120ms ease;
}

.sidebar__link--secondary {
  color: var(--color-muted);
  font-weight: 500;
}

.sidebar__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  flex: 0 0 18px;
}

.sidebar__icon svg {
  width: 18px;
  height: 18px;
}

.sidebar__label {
  min-width: 0;
}

.sidebar__link:hover,
.sidebar__link--active {
  border-color: var(--color-border);
  background: var(--color-surface);
}

.sidebar__link--active {
  color: var(--color-accent);
}

@media (max-width: 1100px) {
  .sidebar {
    position: static;
    height: auto;
    border-right: none;
    border-bottom: 1px solid var(--color-border);
    box-shadow: none;
  }

  .sidebar__group--secondary {
    margin-top: 0;
  }

  .sidebar__nav {
    grid-auto-flow: column;
    grid-auto-columns: max-content;
    overflow-x: auto;
  }
}
</style>
