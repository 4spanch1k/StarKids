<template>
  <PageShell :eyebrow="eyebrow" :title="title" :description="description">
    <template #actions>
      <slot name="actions" />
    </template>

    <div
      class="admin-crud-workspace"
      :class="{ 'admin-crud-workspace--mobile-detail': mobileView === 'detail' }"
    >
      <section class="admin-panel admin-panel--stack admin-crud-workspace__list">
        <slot name="list" />
      </section>

      <aside class="admin-panel admin-panel--stack admin-crud-workspace__detail">
        <AdminMobilePanelHeader
          :title="mobileDetailTitle || title"
          :eyebrow="mobileDetailEyebrow"
          @back="$emit('back')"
        />
        <slot name="detail" />
      </aside>
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import AdminMobilePanelHeader from '@/shared/ui/AdminMobilePanelHeader.vue';
import PageShell from '@/shared/ui/PageShell.vue';

defineProps<{
  eyebrow?: string;
  title: string;
  description?: string;
  mobileView?: 'list' | 'detail';
  mobileDetailTitle?: string;
  mobileDetailEyebrow?: string;
}>();

defineEmits<{
  back: [];
}>();
</script>

<style scoped>
.admin-crud-workspace {
  display: grid;
  grid-template-columns: minmax(360px, 440px) minmax(0, 1fr);
  gap: 14px;
  align-items: start;
}

@media (max-width: 1200px) {
  .admin-crud-workspace {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 960px) {
  .admin-crud-workspace__detail {
    display: none;
  }

  .admin-crud-workspace--mobile-detail .admin-crud-workspace__list {
    display: none;
  }

  .admin-crud-workspace--mobile-detail .admin-crud-workspace__detail {
    display: grid;
  }
}
</style>
