<template>
  <OperationalPreviewPage
    eyebrow="Контент филиалов"
    title="Филиалы"
    description="Управление списком филиалов, контактами и рабочими параметрами."
    :items="[
      {
        id: 'mega-planet',
        label: 'Mega Planet',
        summary: 'Контакты, режим работы и карта маршрута.',
        statusLabel: 'Активен',
        statusTone: 'closed',
      },
      {
        id: 'hyper-house',
        label: 'Hyper House',
        summary: 'Филиал доступен в мобильном приложении.',
        statusLabel: 'Активен',
        statusTone: 'closed',
      },
      {
        id: 'al-farabi',
        label: 'Аль-Фараби',
        summary: 'Новый филиал, контент еще заполняется.',
        statusLabel: 'Черновик',
        statusTone: 'warning',
      },
    ]"
    list-title="Список филиалов"
    detail-description="Выбранный филиал будет открыт справа для проверки и редактирования."
    empty-title="Филиалы пока не добавлены"
    empty-description="Создайте первый филиал, чтобы заполнить контакты, режим работы и контент."
    action-label="Добавить филиал"
    note="Дальше здесь появятся реальные карточки филиалов и формы редактирования."
  />
</template>

<script setup lang="ts">
import OperationalPreviewPage from '@/shared/ui/OperationalPreviewPage.vue';
</script>
