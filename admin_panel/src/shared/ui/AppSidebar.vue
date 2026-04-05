<template>
  <aside class="sidebar">
    <div class="brand">
      <p class="brand-eyebrow">Operations</p>
      <h2>Star Kids</h2>
    </div>

    <nav class="nav">
      <RouterLink
        v-for="item in items"
        :key="item.name"
        :to="item.to"
        class="nav-link"
        active-class="nav-link-active"
      >
        {{ item.label }}
      </RouterLink>
    </nav>
  </aside>
</template>

<script setup lang="ts">
import { RouterLink } from 'vue-router';

import type { NavigationItem } from '@/app/router/navigation';

defineProps<{
  items: NavigationItem[];
}>();
</script>

<style scoped>
.sidebar {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  gap: 24px;
  height: 100vh;
  padding: 24px;
  border-right: 1px solid var(--color-border);
  background: rgba(255, 255, 255, 0.74);
  backdrop-filter: blur(16px);
}

.brand-eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-accent);
}

.brand h2 {
  margin: 0;
  font-size: 24px;
}

.nav {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.nav-link {
  border: 1px solid transparent;
  border-radius: 14px;
  padding: 12px 14px;
  color: var(--color-muted);
  transition: 120ms ease;
}

.nav-link:hover,
.nav-link-active {
  border-color: var(--color-border);
  background: var(--color-accent-soft);
  color: var(--color-text);
}

@media (max-width: 1024px) {
  .sidebar {
    position: static;
    height: auto;
    border-right: none;
    border-bottom: 1px solid var(--color-border);
  }

  .nav {
    overflow-x: auto;
    flex-direction: row;
  }
}
</style>

