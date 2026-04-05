<template>
  <PageShell
    eyebrow="Overview"
    title="Operational summary"
    description="Dashboard should surface lead volume, processing speed, branch activity, and current promotions."
  >
    <div class="stats">
      <article v-for="item in summaryCards" :key="item.label" class="stat-card">
        <p class="label">{{ item.label }}</p>
        <strong>{{ item.value }}</strong>
      </article>
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import PageShell from '@/shared/ui/PageShell.vue';

const summaryCards = [
  { label: 'New leads', value: '18' },
  { label: 'Birthday requests', value: '7' },
  { label: 'Active promotions', value: '4' },
  { label: 'Branches online', value: '2' }
];
</script>

<style scoped>
.stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
}

.stat-card {
  padding: 20px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: #fffaf4;
}

.label {
  margin: 0 0 8px;
  color: var(--color-muted);
}

strong {
  font-size: 28px;
}
</style>

