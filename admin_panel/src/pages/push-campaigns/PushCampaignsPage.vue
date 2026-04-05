<template>
  <PageShell
    eyebrow="Retention"
    title="Push campaigns"
    description="Push campaign management should stay simple in MVP: audience, message, target branch, and send status."
  >
    <ul class="stack">
      <li>Campaign drafts</li>
      <li>Audience filters</li>
      <li>Delivery status overview</li>
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

