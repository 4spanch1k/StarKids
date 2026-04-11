<template>
  <article class="admin-summary-list">
    <div v-if="title || $slots.actions" class="admin-summary-list__header">
      <div class="admin-summary-list__copy">
        <h3 v-if="title">{{ title }}</h3>
        <p v-if="description">{{ description }}</p>
      </div>
      <div v-if="$slots.actions" class="admin-summary-list__actions">
        <slot name="actions" />
      </div>
    </div>

    <dl v-if="items.length" class="admin-summary-list__grid">
      <div
        v-for="item in items"
        :key="item.label"
        :class="{ 'admin-summary-list__item--full': item.fullWidth }"
      >
        <dt>{{ item.label }}</dt>
        <dd>{{ item.value || 'Не указано' }}</dd>
      </div>
    </dl>

    <div v-if="$slots.default" class="admin-summary-list__body">
      <slot />
    </div>
  </article>
</template>

<script setup lang="ts">
type SummaryItem = {
  label: string;
  value: string;
  fullWidth?: boolean;
};

withDefaults(
  defineProps<{
    title?: string;
    description?: string;
    items?: SummaryItem[];
  }>(),
  {
    title: '',
    description: '',
    items: () => [],
  },
);
</script>

<style scoped>
.admin-summary-list {
  display: grid;
  gap: 12px;
  padding: 14px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface-subtle);
}

.admin-summary-list__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}

.admin-summary-list__copy {
  display: grid;
  gap: 4px;
}

.admin-summary-list__copy h3,
.admin-summary-list__copy p,
.admin-summary-list__grid,
.admin-summary-list__grid dt,
.admin-summary-list__grid dd {
  margin: 0;
}

.admin-summary-list__copy p {
  color: var(--color-muted);
  line-height: 1.45;
}

.admin-summary-list__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.admin-summary-list__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.admin-summary-list__item--full {
  grid-column: 1 / -1;
}

.admin-summary-list__grid dt {
  margin-bottom: 4px;
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 600;
}

.admin-summary-list__grid dd {
  line-height: 1.45;
}

.admin-summary-list__body {
  display: grid;
  gap: 10px;
}

@media (max-width: 720px) {
  .admin-summary-list__header {
    flex-direction: column;
  }

  .admin-summary-list__grid {
    grid-template-columns: 1fr;
  }

  .admin-summary-list__actions,
  .admin-summary-list__actions > * {
    width: 100%;
  }
}
</style>
