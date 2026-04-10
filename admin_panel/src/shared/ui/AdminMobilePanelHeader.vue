<template>
  <header class="admin-mobile-panel-header">
    <button
      type="button"
      class="admin-button admin-button--ghost admin-mobile-panel-header__back"
      @click="$emit('back')"
    >
      Назад
    </button>

    <div class="admin-mobile-panel-header__copy">
      <p v-if="eyebrow" class="admin-mobile-panel-header__eyebrow">{{ eyebrow }}</p>
      <strong>{{ title }}</strong>
    </div>
  </header>
</template>

<script setup lang="ts">
defineProps<{
  title: string;
  eyebrow?: string;
}>();

defineEmits<{
  back: [];
}>();
</script>

<style scoped>
.admin-mobile-panel-header {
  display: none;
}

@media (max-width: 960px) {
  .admin-mobile-panel-header {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--color-border);
  }

  .admin-mobile-panel-header__back {
    padding-inline: 0;
  }

  .admin-mobile-panel-header__copy {
    display: grid;
    gap: 2px;
    min-width: 0;
  }

  .admin-mobile-panel-header__eyebrow {
    margin: 0;
    color: var(--color-muted);
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .admin-mobile-panel-header__copy strong {
    font-size: 16px;
    line-height: 1.35;
  }
}
</style>
