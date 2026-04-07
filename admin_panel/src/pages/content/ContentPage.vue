<template>
  <OperationalPreviewPage
    eyebrow="Контент"
    title="Контент приложения"
    description="Здесь должен жить управляемый контент для мобильного приложения: блоки, тексты и порядок показа."
    :items="[
      'Контент-блоки по разделам приложения',
      'Публикация и снятие с публикации',
      'Проверка ключей и порядка отображения',
    ]"
    note="Контент нельзя прятать за сложной структурой. Менеджер должен быстро найти нужный surface и обновить его без ошибок."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
