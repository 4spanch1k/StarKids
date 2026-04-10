<template>
  <Teleport to="body">
    <transition name="admin-route-panel-fade">
      <div v-if="open" class="admin-route-panel">
        <button
          type="button"
          class="admin-route-panel__backdrop"
          aria-label="Закрыть панель"
          @click="$emit('close')"
        ></button>

        <section
          class="admin-route-panel__surface"
          :class="[
            `admin-route-panel__surface--${variant}`,
            { 'admin-route-panel__surface--full': fullScreen },
          ]"
        >
          <header class="admin-route-panel__header">
            <div class="admin-route-panel__header-main">
              <button
                type="button"
                class="admin-route-panel__back"
                @click="$emit('close')"
              >
                {{ closeLabel }}
              </button>

              <div class="admin-route-panel__copy">
                <p v-if="eyebrow" class="admin-route-panel__eyebrow">{{ eyebrow }}</p>
                <h2>{{ title }}</h2>
                <p v-if="description" class="admin-route-panel__description">
                  {{ description }}
                </p>
              </div>
            </div>

            <div v-if="$slots.actions" class="admin-route-panel__actions">
              <slot name="actions" />
            </div>
          </header>

          <div class="admin-route-panel__content">
            <slot />
          </div>
        </section>
      </div>
    </transition>
  </Teleport>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    open: boolean;
    title: string;
    description?: string;
    eyebrow?: string;
    variant?: 'detail' | 'form';
    closeLabel?: string;
    fullScreen?: boolean;
  }>(),
  {
    description: '',
    eyebrow: '',
    variant: 'detail',
    closeLabel: 'Назад',
    fullScreen: false,
  },
);

defineEmits<{
  close: [];
}>();
</script>

<style scoped>
.admin-route-panel {
  position: fixed;
  inset: 0;
  z-index: 70;
}

.admin-route-panel__backdrop {
  position: absolute;
  inset: 0;
  border: 0;
  background: rgba(15, 23, 42, 0.28);
}

.admin-route-panel__surface {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);
  width: min(100%, 820px);
  background: #fff;
  box-shadow: -18px 0 40px rgba(15, 23, 42, 0.16);
}

.admin-route-panel__surface--detail {
  width: min(100%, 560px);
}

.admin-route-panel__surface--full {
  width: 100%;
}

.admin-route-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 14px;
  padding: 18px 20px 14px;
  border-bottom: 1px solid var(--color-border);
  background: #fff;
}

.admin-route-panel__header-main {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  min-width: 0;
}

.admin-route-panel__back {
  min-height: 38px;
  padding: 0 12px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  color: var(--color-text);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}

.admin-route-panel__copy {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.admin-route-panel__copy h2,
.admin-route-panel__eyebrow,
.admin-route-panel__description {
  margin: 0;
}

.admin-route-panel__eyebrow {
  color: var(--color-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.admin-route-panel__description {
  color: var(--color-muted);
  line-height: 1.45;
}

.admin-route-panel__actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.admin-route-panel__content {
  min-height: 0;
  overflow-y: auto;
  padding: 18px 20px 24px;
  background: var(--color-background);
}

.admin-route-panel-fade-enter-active,
.admin-route-panel-fade-leave-active {
  transition: opacity 160ms ease;
}

.admin-route-panel-fade-enter-from,
.admin-route-panel-fade-leave-to {
  opacity: 0;
}

@media (max-width: 1279px) {
  .admin-route-panel__surface,
  .admin-route-panel__surface--detail {
    width: 100%;
  }
}

@media (max-width: 720px) {
  .admin-route-panel__header {
    flex-direction: column;
    gap: 10px;
    padding: 14px 16px 12px;
  }

  .admin-route-panel__header-main {
    width: 100%;
  }

  .admin-route-panel__actions,
  .admin-route-panel__actions > * {
    width: 100%;
  }

  .admin-route-panel__content {
    padding: 14px 16px 22px;
  }
}
</style>
