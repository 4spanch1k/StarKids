<template>
  <section class="admin-compact-filters">
    <div class="admin-compact-filters__primary">
      <slot name="primary" />
    </div>

    <button
      v-if="hasSecondary"
      type="button"
      class="admin-button admin-button--secondary admin-compact-filters__toggle"
      @click="isExpanded = !isExpanded"
    >
      {{ isExpanded ? 'Скрыть фильтры' : 'Фильтры' }}
    </button>

    <div
      v-if="hasSecondary"
      class="admin-compact-filters__secondary"
      :class="{ 'admin-compact-filters__secondary--expanded': isExpanded }"
    >
      <slot name="secondary" />
    </div>
  </section>
</template>

<script setup lang="ts">
import { ref, useSlots } from 'vue';

const slots = useSlots();
const isExpanded = ref(false);

const hasSecondary = Boolean(slots.secondary);
</script>

<style scoped>
.admin-compact-filters {
  display: grid;
  gap: 10px;
}

.admin-compact-filters__toggle {
  display: none;
}

.admin-compact-filters__secondary {
  display: grid;
  gap: 10px;
}

@media (max-width: 767px) {
  .admin-compact-filters__toggle {
    display: inline-flex;
    justify-content: center;
  }

  .admin-compact-filters__secondary {
    display: none;
  }

  .admin-compact-filters__secondary--expanded {
    display: grid;
    padding: 12px;
    border: 1px solid var(--color-border);
    border-radius: 14px;
    background: var(--color-surface-subtle);
  }
}
</style>
