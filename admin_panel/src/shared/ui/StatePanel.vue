<template>
  <div class="state-panel" :class="toneClass">
    <div class="state-panel__copy">
      <h3 class="state-panel__title">{{ title }}</h3>
      <p v-if="description" class="state-panel__description">
        {{ description }}
      </p>
    </div>
    <div v-if="$slots.actions" class="state-panel__actions">
      <slot name="actions" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    title: string;
    description?: string;
    tone?: 'neutral' | 'error' | 'success';
  }>(),
  {
    description: '',
    tone: 'neutral',
  },
);

const toneClass = computed(() => `state-panel--${props.tone}`);
</script>

<style scoped>
.state-panel {
  display: grid;
  gap: 16px;
  padding: 24px;
  border: 1px dashed var(--color-border-strong);
  border-radius: 20px;
  background: var(--color-surface-subtle);
}

.state-panel--error {
  border-color: rgba(180, 35, 24, 0.18);
  background: var(--color-danger-soft);
}

.state-panel--success {
  border-color: rgba(16, 124, 65, 0.18);
  background: var(--color-success-soft);
}

.state-panel__copy {
  display: grid;
  gap: 8px;
}

.state-panel__title {
  margin: 0;
  font-size: 18px;
  line-height: 1.35;
}

.state-panel__description {
  margin: 0;
  color: var(--color-muted);
  line-height: 1.6;
}

.state-panel__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}
</style>
