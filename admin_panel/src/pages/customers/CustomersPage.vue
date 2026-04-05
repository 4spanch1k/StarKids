<template>
  <PageShell
    eyebrow="CRM"
    title="Customers"
    description="Customer list is the base for future segmentation, request history, and repeat-use analysis."
  >
    <ul class="stack">
      <li>Phone-based customer records</li>
      <li>Preferred branch</li>
      <li>Push registration status</li>
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

