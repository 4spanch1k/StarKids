<template>
  <PageShell
    eyebrow="Commercial content"
    title="Branches"
    description="Branches own contacts, maps, operating hours, media, and promotion targeting."
  >
    <div class="list">
      <article v-for="branch in branches" :key="branch.id" class="row">
        <div>
          <strong>{{ branch.name }}</strong>
          <p>{{ branch.city }} · {{ branch.address }}</p>
        </div>
        <span>{{ branch.isActive ? 'Active' : 'Draft' }}</span>
      </article>
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import type { Branch } from '@/entities/branch/model/branch';
import PageShell from '@/shared/ui/PageShell.vue';

const branches: Branch[] = [
  {
    id: 'branch-1',
    name: 'Star Kids Mega',
    city: 'Shymkent',
    address: 'Tamerlan Highway',
    isActive: true
  },
  {
    id: 'branch-2',
    name: 'Star Kids Center',
    city: 'Shymkent',
    address: 'Republic Avenue',
    isActive: true
  }
];
</script>

<style scoped>
.list {
  display: grid;
  gap: 12px;
}

.row {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  padding: 18px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
}

.row p {
  margin: 6px 0 0;
  color: var(--color-muted);
}
</style>

