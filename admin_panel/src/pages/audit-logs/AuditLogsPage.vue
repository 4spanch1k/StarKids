<template>
  <OperationalPreviewPage
    eyebrow="Системный контроль"
    title="Журнал аудита"
    description="Здесь должен собираться понятный журнал действий, чтобы команда видела, кто и когда менял заявки и контент."
    :items="[
      'История входов в админ-панель',
      'Изменения статусов по заявкам',
      'Изменения контента, акций и филиалов',
    ]"
    note="Журнал особенно важен, когда в панели начинает работать несколько сотрудников одновременно."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
