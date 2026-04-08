<template>
  <OperationalPreviewPage
    eyebrow="Медиа"
    title="Галерея"
    description="Управление медиа по филиалам и сценариям использования."
    :items="[
      {
        id: 'branches-gallery',
        label: 'Филиалы',
        summary: 'Фото зон и общие hero-изображения.',
        statusLabel: 'Активно',
        statusTone: 'closed',
      },
      {
        id: 'birthday-gallery',
        label: 'Праздники',
        summary: 'Подборки для birthday surfaces.',
        statusLabel: 'В работе',
        statusTone: 'in-progress',
      },
      {
        id: 'play-zones-gallery',
        label: 'Игровые зоны',
        summary: 'Раздел еще не заполнен.',
        statusLabel: 'Черновик',
        statusTone: 'neutral',
      },
    ]"
    list-title="Наборы медиа"
    detail-description="Справа будет показана выбранная медиаподборка и ее текущее состояние."
    empty-title="Галерея пока пустая"
    empty-description="Добавьте первую подборку, чтобы команда могла управлять медиа без хаоса."
    action-label="Добавить медиа"
    note="Когда backend и upload-flow будут готовы, этот раздел уже не придется переделывать целиком."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
