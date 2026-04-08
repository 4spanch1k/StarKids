<template>
  <OperationalPreviewPage
    eyebrow="Клиентская база"
    title="Клиенты"
    description="Раздел нужен как спокойная база для будущей истории обращений, сегментации и связи с push-статусом."
    :items="[
      'Телефон и имя клиента',
      'Предпочтительный филиал',
      'Признаки активности и повторных обращений',
    ]"
    note="Сейчас этот раздел вторичен. Важно не выпячивать его в навигации, но foundation должен быть понятным и готовым к росту."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
