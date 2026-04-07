<template>
  <OperationalPreviewPage
    eyebrow="Медиа"
    title="Галерея"
    description="Галерея должна управляться как спокойный рабочий инструмент: без хаоса, с понятной структурой по филиалам и типам изображений."
    :items="[
      'Hero-изображения филиалов',
      'Галереи по зонам и праздникам',
      'Порядок и актуальность медиа',
    ]"
    note="В дальнейшем здесь должен появиться понятный upload-driven поток, но foundation уже сейчас должен быть чистым и предсказуемым."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
