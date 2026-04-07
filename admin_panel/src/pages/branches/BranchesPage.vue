<template>
  <OperationalPreviewPage
    eyebrow="Контент филиалов"
    title="Филиалы"
    description="Филиал — это база для контактов, карты, графика работы, тарифов и branch-aware контента в мобильном приложении."
    :items="[
      'Основная информация и короткое описание',
      'Контакты и маршрут',
      'График работы и статус филиала',
    ]"
    note="Сотруднику не нужно искать данные по разным вкладкам. Все ключевое должно быть собрано вокруг одного филиала."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
