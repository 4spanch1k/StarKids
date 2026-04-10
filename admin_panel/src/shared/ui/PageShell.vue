<template>
  <section class="page-shell">
    <header class="page-shell__header">
      <div class="page-shell__copy">
        <p v-if="eyebrow" class="page-shell__eyebrow">{{ eyebrow }}</p>
        <h1 class="page-shell__title">{{ title }}</h1>
        <p class="page-shell__description">{{ description }}</p>
      </div>
      <div v-if="$slots.actions" class="page-shell__actions">
        <slot name="actions" />
      </div>
    </header>

    <div class="page-shell__body">
      <slot />
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  eyebrow?: string;
  title: string;
  description: string;
}>();
</script>

<style scoped>
.page-shell {
  display: grid;
  gap: 18px;
}

.page-shell__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.page-shell__copy {
  display: grid;
  gap: 6px;
  max-width: 760px;
}

.page-shell__eyebrow {
  margin: 0;
  font-size: 13px;
  font-weight: 700;
  color: var(--color-muted);
}

.page-shell__title {
  margin: 0;
  font-size: 28px;
  line-height: 1.15;
}

.page-shell__description {
  margin: 0;
  color: var(--color-muted);
  line-height: 1.55;
}

.page-shell__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.page-shell__body {
  display: grid;
  gap: 14px;
}

@media (max-width: 900px) {
  .page-shell__header {
    flex-direction: column;
  }
}
</style>
