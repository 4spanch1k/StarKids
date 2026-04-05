<template>
  <PageShell
    eyebrow="Support content"
    title="FAQ"
    description="FAQ content reduces operator load and helps mobile users answer simple questions before submitting a request."
  >
    <ul class="stack">
      <li>Question and answer management</li>
      <li>Sorting by priority</li>
      <li>Visibility controls</li>
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

