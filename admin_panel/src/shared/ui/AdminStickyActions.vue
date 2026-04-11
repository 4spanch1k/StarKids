<template>
  <div class="admin-sticky-actions">
    <slot />
  </div>
</template>

<style scoped>
.admin-sticky-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

@media (max-width: 720px) {
  .admin-sticky-actions {
    position: sticky;
    bottom: 0;
    z-index: 5;
    margin-top: 4px;
    padding: 12px 0 calc(env(safe-area-inset-bottom, 0px) + 2px);
    background:
      linear-gradient(
        180deg,
        rgba(246, 248, 252, 0) 0%,
        rgba(246, 248, 252, 0.95) 26%,
        rgba(246, 248, 252, 1) 100%
      );
  }

  .admin-sticky-actions :deep(.admin-button) {
    flex: 1 1 0;
    min-width: 0;
  }
}
</style>
