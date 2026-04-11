<template>
  <PageShell :eyebrow="eyebrow" :title="title" :description="description">
    <template #actions>
      <slot name="actions" />
    </template>

    <div
      class="admin-crud-workspace"
      :class="{ 'admin-crud-workspace--with-detail': showDetail }"
    >
      <section class="admin-panel admin-panel--stack admin-crud-workspace__list">
        <slot name="list" />
      </section>

      <aside
        v-if="showDetail"
        class="admin-panel admin-panel--stack admin-crud-workspace__detail"
      >
        <slot name="detail" />
      </aside>
    </div>

    <AdminRoutePanel
      :open="routePanelOpen"
      :title="routePanelTitle || title"
      :description="routePanelDescription"
      :eyebrow="routePanelEyebrow"
      :variant="routePanelVariant"
      :close-label="routePanelCloseLabel"
      @close="$emit('back')"
    >
      <template v-if="$slots.routeActions" #actions>
        <slot name="routeActions" />
      </template>

      <slot name="detail" />
    </AdminRoutePanel>
  </PageShell>
</template>

<script setup lang="ts">
import AdminRoutePanel from '@/shared/ui/AdminRoutePanel.vue';
import PageShell from '@/shared/ui/PageShell.vue';

withDefaults(
  defineProps<{
    eyebrow?: string;
    title: string;
    description?: string;
    showDetail?: boolean;
    routePanelOpen?: boolean;
    routePanelTitle?: string;
    routePanelDescription?: string;
    routePanelEyebrow?: string;
    routePanelVariant?: 'detail' | 'form';
    routePanelCloseLabel?: string;
  }>(),
  {
    eyebrow: '',
    description: '',
    showDetail: false,
    routePanelOpen: false,
    routePanelTitle: '',
    routePanelDescription: '',
    routePanelEyebrow: '',
    routePanelVariant: 'detail',
    routePanelCloseLabel: 'Назад',
  },
);

defineEmits<{
  back: [];
}>();
</script>

<style scoped>
.admin-crud-workspace {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 16px;
  align-items: start;
}

@media (min-width: 1280px) {
  .admin-crud-workspace--with-detail {
    grid-template-columns: minmax(340px, 420px) minmax(0, 1fr);
  }

  .admin-crud-workspace__detail {
    min-width: 0;
  }
}
</style>
