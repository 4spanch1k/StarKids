<template>
  <PageShell
    eyebrow="Monetization"
    title="Birthday packages"
    description="Packages should define offer structure, included services, add-ons, and branch availability."
  >
    <ul class="stack">
      <li>Package list and availability management</li>
      <li>Included items and extra services</li>
      <li>Lead conversion visibility by package</li>
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

