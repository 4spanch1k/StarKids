<template>
  <div class="admin-form-error-banner" role="alert">
    <p class="admin-form-error-banner__title">{{ message }}</p>
    <ul v-if="errorItems.length" class="admin-form-error-banner__list">
      <li v-for="item in errorItems" :key="item">
        {{ item }}
      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import type { AdminFieldErrors } from '@/shared/lib/adminApiErrors';

const props = withDefaults(
  defineProps<{
    message: string;
    errors?: AdminFieldErrors;
  }>(),
  {
    errors: () => ({}),
  },
);

const errorItems = computed(() => {
  return [...new Set(Object.values(props.errors))];
});
</script>

<style scoped>
.admin-form-error-banner {
  display: grid;
  gap: 8px;
  padding: 12px 14px;
  border: 1px solid rgba(180, 35, 24, 0.16);
  border-radius: 14px;
  background: var(--color-danger-soft);
}

.admin-form-error-banner__title {
  margin: 0;
  color: var(--color-danger);
  font-size: 14px;
  font-weight: 700;
  line-height: 1.45;
}

.admin-form-error-banner__list {
  display: grid;
  gap: 4px;
  margin: 0;
  padding-left: 18px;
  color: var(--color-danger);
  font-size: 13px;
  line-height: 1.45;
}
</style>
