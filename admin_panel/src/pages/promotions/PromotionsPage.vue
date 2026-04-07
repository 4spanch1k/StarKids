<template>
  <OperationalPreviewPage
    eyebrow="Акции"
    title="Акции"
    description="Экран акций должен помогать быстро обновлять branch-aware предложения и не путать сотрудников лишними полями."
    :items="[
      'Список активных и черновых акций',
      'Филиалы, к которым относится акция',
      'Текст оффера и CTA',
    ]"
    note="Оператору должно быть понятно, что сейчас опубликовано, где действует акция и что увидит родитель в мобильном приложении."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
