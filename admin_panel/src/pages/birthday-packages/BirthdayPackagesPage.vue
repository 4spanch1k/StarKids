<template>
  <OperationalPreviewPage
    eyebrow="Коммерческое предложение"
    title="Пакеты дней рождения"
    description="Управление пакетами, составом услуг и доступностью по филиалам."
    :items="[
      {
        id: 'star-show',
        label: 'Star Show',
        summary: 'Флагманский пакет с аниматором и шоу.',
        statusLabel: 'Опубликован',
        statusTone: 'closed',
      },
      {
        id: 'mini-party',
        label: 'Mini Party',
        summary: 'Компактный пакет для небольших групп.',
        statusLabel: 'Опубликован',
        statusTone: 'closed',
      },
      {
        id: 'weekend-boost',
        label: 'Weekend Boost',
        summary: 'Подготовлен, но еще не опубликован.',
        statusLabel: 'Черновик',
        statusTone: 'warning',
      },
    ]"
    list-title="Список пакетов"
    detail-description="Справа будет открыт выбранный пакет с составом услуг и состоянием публикации."
    empty-title="Пакетов пока нет"
    empty-description="Добавьте первый пакет, чтобы команда могла поддерживать предложение в актуальном состоянии."
    action-label="Добавить пакет"
    note="Следующим шагом сюда можно посадить реальный list-detail CRUD."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
