<template>
  <span class="status-badge" :class="toneClass">
    {{ label }}
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    label: string;
    tone?: 'neutral' | 'new' | 'in-progress' | 'closed' | 'warning' | 'danger';
  }>(),
  {
    tone: 'neutral',
  },
);

const toneClass = computed(() => `status-badge--${props.tone}`);
</script>

<style scoped>
.status-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 28px;
  padding: 0 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
  line-height: 1;
  white-space: nowrap;
}

.status-badge--neutral {
  background: var(--color-surface-subtle);
  color: var(--color-text);
}

.status-badge--new {
  background: var(--color-accent-soft);
  color: var(--color-accent);
}

.status-badge--in-progress,
.status-badge--warning {
  background: var(--color-warning-soft);
  color: var(--color-warning);
}

.status-badge--closed {
  background: var(--color-success-soft);
  color: var(--color-success);
}

.status-badge--danger {
  background: var(--color-danger-soft);
  color: var(--color-danger);
}
</style>
