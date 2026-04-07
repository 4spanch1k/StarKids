<template>
  <OperationalPreviewPage
    eyebrow="Справочный контент"
    title="Частые вопросы"
    description="Раздел должен помогать поддерживать ответы на типовые вопросы так, чтобы это снижало нагрузку на операторов."
    :items="[
      'Список вопросов и ответов',
      'Порядок отображения',
      'Управление публикацией',
    ]"
    note="Для контент-менеджера здесь важны ясные формулировки и быстрый контроль, что именно увидит пользователь в приложении."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
