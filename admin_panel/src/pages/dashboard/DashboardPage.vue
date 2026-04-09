<template>
  <OperationalPreviewPage
    eyebrow="Сводка"
    title="Операционная сводка"
    description="Сводка не должна конкурировать с рабочими разделами. Ее задача — быстро показать нагрузку и исключения."
    :items="[
      'Новые заявки за день',
      'Заявки в работе и просрочки',
      'Филиалы и активные акции',
    ]"
    note="Главный рабочий экран для сотрудника — это заявки. Сводка нужна как вторичный обзор, а не как отдельный продукт."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
