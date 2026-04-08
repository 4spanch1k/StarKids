<template>
  <OperationalPreviewPage
    eyebrow="Справочный контент"
    title="Частые вопросы"
    description="Управление ответами на типовые вопросы пользователей."
    :items="[
      {
        id: 'faq-booking',
        label: 'Бронирование',
        summary: 'Вопросы по времени, подтверждению и датам.',
        statusLabel: 'Опубликован',
        statusTone: 'closed',
      },
      {
        id: 'faq-payment',
        label: 'Оплата',
        summary: 'Ответы по оплате и возвратам.',
        statusLabel: 'Опубликован',
        statusTone: 'closed',
      },
      {
        id: 'faq-rules',
        label: 'Правила посещения',
        summary: 'Раздел готовится к публикации.',
        statusLabel: 'Черновик',
        statusTone: 'neutral',
      },
    ]"
    list-title="Темы FAQ"
    detail-description="Справа будет показана выбранная тема FAQ и ее рабочий статус."
    empty-title="FAQ пока не заполнен"
    empty-description="Добавьте первый вопрос, чтобы пользователи и операторы быстрее находили ответы."
    action-label="Добавить вопрос"
    note="Позже сюда легко подключить реальное управление вопросами и сортировкой."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
