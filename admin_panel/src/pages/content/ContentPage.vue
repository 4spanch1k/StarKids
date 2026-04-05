<template>
  <PageShell
    eyebrow="Content"
    title="App content"
    description="Home banners, section ordering, legal pages, and static copy should be managed outside the mobile client."
  >
    <ul class="stack">
      <li>Home banners</li>
      <li>Section ordering</li>
      <li>Legal page publishing</li>
    </ul>
  </PageShell>
</template>

<script setup lang="ts">
import PageShell from '@/shared/ui/PageShell.vue';
</script>

<style scoped>
.stack {
  display: grid;
  gap: 12px;
  margin: 0;
  padding-left: 18px;
}
</style>

