<template>
  <section class="page-shell">
    <header class="page-header">
      <div>
        <p class="eyebrow">{{ eyebrow }}</p>
        <h2>{{ title }}</h2>
      </div>
      <slot name="actions" />
    </header>

    <p class="description">{{ description }}</p>

    <div class="panel">
      <slot />
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  eyebrow: string;
  title: string;
  description: string;
}>();
</script>

<style scoped>
.page-shell {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-accent);
}

.page-header h2 {
  margin: 0;
  font-size: 22px;
}

.description {
  margin: 0;
  max-width: 760px;
  color: var(--color-muted);
  line-height: 1.6;
}

.panel {
  border: 1px solid var(--color-border);
  border-radius: 24px;
  padding: 24px;
  background: var(--color-surface);
  box-shadow: var(--shadow-soft);
}
</style>

