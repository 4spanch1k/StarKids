<template>
  <PageShell :eyebrow="eyebrow" :title="title" :description="description">
    <div class="preview-layout">
      <section class="admin-panel admin-panel--stack">
        <div class="admin-section-heading">
          <h2>{{ primaryTitle }}</h2>
          <p>{{ primaryDescription }}</p>
        </div>
        <ul class="preview-list">
          <li v-for="item in items" :key="item">{{ item }}</li>
        </ul>
      </section>

      <aside class="admin-panel admin-panel--muted admin-panel--stack">
        <div class="admin-section-heading">
          <h2>{{ secondaryTitle }}</h2>
          <p>{{ secondaryDescription }}</p>
        </div>
        <slot>
          <p class="admin-copy-muted">{{ note }}</p>
        </slot>
      </aside>
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import PageShell from '@/shared/ui/PageShell.vue';

withDefaults(
  defineProps<{
    eyebrow?: string;
    title: string;
    description: string;
    items: string[];
    note: string;
    primaryTitle?: string;
    primaryDescription?: string;
    secondaryTitle?: string;
    secondaryDescription?: string;
  }>(),
  {
    eyebrow: '',
    primaryTitle: 'Что должно быть под рукой',
    primaryDescription: 'Только ключевые действия, которые реально нужны сотруднику в работе.',
    secondaryTitle: 'Зачем это нужно',
    secondaryDescription: 'Экран должен помогать работать быстрее, а не добавлять лишние клики.',
  },
);
</script>

<style scoped>
.preview-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.3fr) minmax(280px, 0.9fr);
  gap: 20px;
}

.preview-list {
  display: grid;
  gap: 12px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.preview-list li {
  position: relative;
  padding-left: 22px;
  line-height: 1.5;
}

.preview-list li::before {
  content: '';
  position: absolute;
  top: 8px;
  left: 0;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: var(--color-accent);
}

@media (max-width: 1100px) {
  .preview-layout {
    grid-template-columns: 1fr;
  }
}
</style>
