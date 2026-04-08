<template>
  <OperationalPreviewPage
    eyebrow="Контент"
    title="Контент приложения"
    description="Управление контентными блоками мобильного приложения и порядком показа."
    :items="[
      {
        id: 'home-content',
        label: 'Главный экран',
        summary: 'Блоки первого экрана и порядок показа.',
        statusLabel: 'В работе',
        statusTone: 'in-progress',
      },
      {
        id: 'birthdays-content',
        label: 'Дни рождения',
        summary: 'Промо-блоки и тексты пакетов.',
        statusLabel: 'Активен',
        statusTone: 'closed',
      },
      {
        id: 'promotions-content',
        label: 'Акции',
        summary: 'Тексты и CTA для мобильной витрины акций.',
        statusLabel: 'Черновик',
        statusTone: 'neutral',
      },
    ]"
    list-title="Контентные поверхности"
    detail-description="Справа будет открыта выбранная поверхность с описанием и рабочими действиями."
    empty-title="Контент пока не настроен"
    empty-description="Создайте первый блок, чтобы команда могла управлять текстами и порядком показа."
    action-label="Добавить блок"
    note="Следующий шаг для этого раздела — реальные формы редактирования и публикации."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
