<template>
  <PageShell
    eyebrow="Security"
    title="Audit logs"
    description="Administrative changes should be traceable before the project grows beyond a single operator."
  >
    <ul class="stack">
      <li>Authentication events</li>
      <li>Content and promotion changes</li>
      <li>Lead status history</li>
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

