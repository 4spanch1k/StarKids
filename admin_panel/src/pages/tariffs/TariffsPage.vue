<template>
  <PageShell
    eyebrow="Commercial content"
    title="Tariffs and rules"
    description="Tariffs, visit conditions, and rule text should stay structured so mobile content remains easy to update."
  >
    <ul class="stack">
      <li>Visit tariff definitions</li>
      <li>Branch-specific pricing</li>
      <li>Rules and disclaimers</li>
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

