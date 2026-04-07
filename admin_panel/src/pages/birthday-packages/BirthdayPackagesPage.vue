<template>
  <OperationalPreviewPage
    eyebrow="Коммерческое предложение"
    title="Пакеты дней рождения"
    description="Экран должен помогать быстро поддерживать актуальные пакеты, состав услуг и branch-aware доступность."
    :items="[
      'Список пакетов и их статус',
      'Состав пакета и дополнительные услуги',
      'Привязка пакета к филиалу',
    ]"
    note="Для сотрудника здесь важно быстро понять, какой пакет сейчас активен и что входит в предложение."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
