<template>
  <OperationalPreviewPage
    eyebrow="Коммерческие условия"
    title="Тарифы и правила"
    description="Раздел нужен для поддержки тарифов посещения и правил, которые потом показываются в мобильном приложении."
    :items="[
      'Тарифы посещения по филиалу',
      'Правила и disclaimers',
      'Связь с экраном цен в приложении',
    ]"
    note="Сейчас раздел вторичен в навигации. Важно не перегружать его, а сделать понятной точкой настройки условий."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
