<template>
  <PageShell
    eyebrow="Retention"
    title="Promotions"
    description="Promotions should connect content, push campaigns, and branch targeting."
  >
    <ul class="stack">
      <li>Seasonal offers</li>
      <li>Branch targeting</li>
      <li>Launch dates and campaign visibility</li>
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

