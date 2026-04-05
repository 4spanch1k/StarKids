<template>
  <div class="layout">
    <AppSidebar :items="navigationItems" />
    <main class="content">
      <header class="topbar">
        <div>
          <p class="eyebrow">Star Kids Admin</p>
          <h1>{{ currentLabel }}</h1>
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
import { RouterView, useRoute } from 'vue-router';

import { navigationItems } from '@/app/router/navigation';
import AppSidebar from '@/shared/ui/AppSidebar.vue';

const route = useRoute();

const currentLabel = computed(() => {
  return navigationItems.find((item) => item.name === route.name)?.label ?? 'Admin';
});
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

@media (max-width: 1024px) {
  .layout {
    grid-template-columns: 1fr;
  }
}
</style>

