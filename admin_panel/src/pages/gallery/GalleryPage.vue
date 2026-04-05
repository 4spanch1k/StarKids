<template>
  <PageShell
    eyebrow="Media"
    title="Gallery and media"
    description="Media should be upload-driven and reusable across home, branches, and promotions."
  >
    <ul class="stack">
      <li>Branch gallery collections</li>
      <li>Compression and ordering policies</li>
      <li>Shared media library</li>
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

