<template>
  <PageShell
    eyebrow="Lead inbox"
    title="Customer requests"
    description="This module should centralize birthday, callback, and group requests with filters by branch, status, and date."
  >
    <div class="list">
      <article v-for="lead in leads" :key="lead.id" class="row">
        <div>
          <strong>{{ lead.customerName }}</strong>
          <p>{{ lead.branchName }} · {{ lead.type }}</p>
        </div>
        <span class="status">{{ lead.status }}</span>
      </article>
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import type { Lead } from '@/entities/lead/model/lead';
import PageShell from '@/shared/ui/PageShell.vue';

const leads: Lead[] = [
  {
    id: 'lead-1',
    type: 'birthday',
    branchName: 'Star Kids Mega',
    customerName: 'Aruzhan K.',
    status: 'new'
  },
  {
    id: 'lead-2',
    type: 'callback',
    branchName: 'Star Kids Center',
    customerName: 'Dias M.',
    status: 'in_progress'
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
  align-items: center;
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

.status {
  border-radius: 999px;
  padding: 8px 12px;
  background: var(--color-accent-soft);
}
</style>

