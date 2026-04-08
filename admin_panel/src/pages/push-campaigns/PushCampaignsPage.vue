<template>
  <OperationalPreviewPage
    eyebrow="Удержание"
    title="Пуш-кампании"
    description="Пуш-кампании остаются вторичным разделом. В базовом слое панели важно не выпячивать его раньше времени, но сохранить спокойную точку входа."
    :items="[
      'Черновики пуш-кампаний',
      'Филиал и целевой сегмент',
      'Статус отправки',
    ]"
    note="Когда раздел станет активным, оператору должен быть понятен один главный сценарий: подготовить сообщение и безопасно отправить его."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
