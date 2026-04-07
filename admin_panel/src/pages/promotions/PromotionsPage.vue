<template>
  <OperationalPreviewPage
    eyebrow="Акции"
    title="Акции"
    description="Управление активными акциями и их публикацией по филиалам."
    :items="[
      {
        id: 'weekday-discount',
        label: 'Скидка в будни',
        summary: 'Акция видна в мобильном приложении.',
        statusLabel: 'Опубликована',
        statusTone: 'closed',
      },
      {
        id: 'group-combo',
        label: 'Комбо для группы',
        summary: 'Готова к запуску по нескольким филиалам.',
        statusLabel: 'Черновик',
        statusTone: 'warning',
      },
      {
        id: 'return-visit',
        label: 'Повторный визит',
        summary: 'Временно снята с публикации.',
        statusLabel: 'Пауза',
        statusTone: 'neutral',
      },
    ]"
    list-title="Список акций"
    detail-description="Выбранная акция будет открыта справа для проверки оффера, статуса и филиалов."
    empty-title="Акции пока не заведены"
    empty-description="Добавьте первую акцию, чтобы команда могла управлять офферами без ручных правок в коде."
    action-label="Добавить акцию"
    note="Позже этот раздел можно посадить на существующий backend CRUD без смены shell."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
