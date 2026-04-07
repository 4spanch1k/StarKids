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
          {{ item.label }}
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
          {{ item.label }}
        </RouterLink>
      </nav>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { RouterLink } from 'vue-router';

import type { NavigationItem } from '@/app/router/navigation';

withDefaults(
  defineProps<{
    primaryItems: NavigationItem[];
    secondaryItems?: NavigationItem[];
  }>(),
  {
    secondaryItems: () => [],
  },
);
</script>

<style scoped>
.sidebar {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  gap: 28px;
  height: 100vh;
  padding: 28px 22px;
  border-right: 1px solid var(--color-border);
  background: linear-gradient(180deg, #f7f8fb 0%, #f3f5f8 100%);
  box-shadow: var(--shadow-sidebar);
}

.sidebar__brand {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 8px 6px 4px;
}

.sidebar__logo {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: 14px;
  background: var(--color-text);
  color: #fff;
  font-size: 15px;
  font-weight: 700;
}

.sidebar__copy {
  min-width: 0;
}

.sidebar__eyebrow {
  margin: 0 0 4px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-muted);
}

.sidebar__copy h2 {
  margin: 0;
  font-size: 18px;
  line-height: 1.3;
}

.sidebar__group {
  display: grid;
  gap: 12px;
}

.sidebar__group--secondary {
  margin-top: auto;
}

.sidebar__group-title {
  margin: 0;
  padding-left: 10px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-muted);
}

.sidebar__nav {
  display: grid;
  gap: 6px;
}

.sidebar__link {
  display: flex;
  align-items: center;
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid transparent;
  border-radius: 14px;
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
