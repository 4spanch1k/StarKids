<template>
  <div ref="rootRef" class="admin-field date-range-field">
    <span class="admin-field__label">{{ label }}</span>

    <button
      type="button"
      class="date-range-field__trigger"
      :class="{ 'date-range-field__trigger--open': isOpen }"
      :disabled="disabled"
      @click="toggleOpen"
    >
      <span class="date-range-field__summary">{{ summaryLabel }}</span>
      <span class="date-range-field__chevron" aria-hidden="true">▾</span>
    </button>

    <div v-if="isOpen" class="date-range-field__popover">
      <div class="date-range-field__quick-actions">
        <button type="button" class="date-range-field__quick-button" @click="applyToday">
          Сегодня
        </button>
        <button type="button" class="date-range-field__quick-button" @click="applyNextSevenDays">
          7 дней
        </button>
        <button type="button" class="date-range-field__quick-button" @click="clearRange">
          Сбросить
        </button>
      </div>

      <div class="date-range-field__current-range">
        <span>{{ formatValue(modelValue.from) }}</span>
        <span class="date-range-field__range-separator">—</span>
        <span>{{ formatValue(modelValue.to) }}</span>
      </div>

      <div class="date-range-field__calendar">
        <div class="date-range-field__calendar-header">
          <button type="button" class="date-range-field__nav" @click="showPreviousMonth">
            ‹
          </button>
          <strong>{{ monthTitle }}</strong>
          <button type="button" class="date-range-field__nav" @click="showNextMonth">
            ›
          </button>
        </div>

        <div class="date-range-field__weekdays">
          <span v-for="weekday in weekdays" :key="weekday">{{ weekday }}</span>
        </div>

        <div class="date-range-field__days">
          <button
            v-for="day in calendarDays"
            :key="day.key"
            type="button"
            class="date-range-field__day"
            :class="{
              'date-range-field__day--muted': !day.isCurrentMonth,
              'date-range-field__day--selected': day.isSelected,
              'date-range-field__day--range': day.isInRange,
            }"
            @click="selectDate(day.iso)"
          >
            {{ day.date.getDate() }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';

type DateRangeValue = {
  from: string;
  to: string;
};

type CalendarDay = {
  key: string;
  date: Date;
  iso: string;
  isCurrentMonth: boolean;
  isSelected: boolean;
  isInRange: boolean;
};

const props = withDefaults(
  defineProps<{
    label: string;
    modelValue: DateRangeValue;
    disabled?: boolean;
  }>(),
  {
    disabled: false,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: DateRangeValue];
}>();

const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const rootRef = ref<HTMLElement | null>(null);
const isOpen = ref(false);
const visibleMonth = ref(resolveInitialMonth(props.modelValue.from));

const summaryLabel = computed(() => {
  const { from, to } = props.modelValue;
  if (!from && !to) {
    return 'Выберите период';
  }
  if (from && !to) {
    return `${formatValue(from)} — ...`;
  }
  return `${formatValue(from)} — ${formatValue(to)}`;
});

const monthTitle = computed(() => {
  return new Intl.DateTimeFormat('ru-RU', {
    month: 'long',
    year: 'numeric',
  }).format(visibleMonth.value);
});

const calendarDays = computed<CalendarDay[]>(() => {
  const monthStart = startOfMonth(visibleMonth.value);
  const gridStart = startOfCalendarGrid(monthStart);

  return Array.from({ length: 42 }, (_, index) => {
    const date = addDays(gridStart, index);
    const iso = toIsoDate(date);
    const from = props.modelValue.from;
    const to = props.modelValue.to;

    return {
      key: `${iso}-${index}`,
      date,
      iso,
      isCurrentMonth: date.getMonth() === monthStart.getMonth(),
      isSelected: iso === from || iso === to,
      isInRange: Boolean(from && to && iso > from && iso < to),
    };
  });
});

function toggleOpen() {
  if (props.disabled) {
    return;
  }

  isOpen.value = !isOpen.value;
}

function selectDate(iso: string) {
  const { from, to } = props.modelValue;

  if (!from || (from && to)) {
    emit('update:modelValue', { from: iso, to: '' });
    return;
  }

  if (iso < from) {
    emit('update:modelValue', { from: iso, to: '' });
    return;
  }

  emit('update:modelValue', { from, to: iso });
  isOpen.value = false;
}

function clearRange() {
  emit('update:modelValue', { from: '', to: '' });
}

function applyToday() {
  const today = toIsoDate(new Date());
  emit('update:modelValue', { from: today, to: today });
  isOpen.value = false;
}

function applyNextSevenDays() {
  const today = startOfDay(new Date());
  emit('update:modelValue', {
    from: toIsoDate(today),
    to: toIsoDate(addDays(today, 6)),
  });
  isOpen.value = false;
}

function showPreviousMonth() {
  visibleMonth.value = new Date(
    visibleMonth.value.getFullYear(),
    visibleMonth.value.getMonth() - 1,
    1,
  );
}

function showNextMonth() {
  visibleMonth.value = new Date(
    visibleMonth.value.getFullYear(),
    visibleMonth.value.getMonth() + 1,
    1,
  );
}

function handleDocumentClick(event: MouseEvent) {
  if (!rootRef.value) {
    return;
  }

  const target = event.target;
  if (target instanceof Node && !rootRef.value.contains(target)) {
    isOpen.value = false;
  }
}

function formatValue(value: string) {
  if (!value) {
    return 'Не выбрано';
  }

  return new Intl.DateTimeFormat('ru-RU', {
    day: '2-digit',
    month: 'short',
  }).format(new Date(`${value}T00:00:00`));
}

function resolveInitialMonth(value: string) {
  if (!value) {
    return startOfMonth(new Date());
  }

  return startOfMonth(new Date(`${value}T00:00:00`));
}

function startOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function startOfMonth(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function startOfCalendarGrid(monthStart: Date) {
  const jsWeekday = monthStart.getDay();
  const offset = jsWeekday === 0 ? 6 : jsWeekday - 1;
  return addDays(monthStart, -offset);
}

function addDays(date: Date, days: number) {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

function toIsoDate(date: Date) {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}

onMounted(() => {
  document.addEventListener('mousedown', handleDocumentClick);
});

onBeforeUnmount(() => {
  document.removeEventListener('mousedown', handleDocumentClick);
});
</script>

<style scoped>
.date-range-field {
  position: relative;
}

.date-range-field__trigger {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  width: 100%;
  min-height: 38px;
  padding: 0 12px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  color: var(--color-text);
  text-align: left;
  cursor: pointer;
  transition:
    border-color 120ms ease,
    box-shadow 120ms ease,
    background-color 120ms ease;
}

.date-range-field__trigger:hover:not(:disabled),
.date-range-field__trigger--open {
  border-color: var(--color-border-strong);
  box-shadow: 0 0 0 2px rgba(208, 47, 112, 0.08);
}

.date-range-field__trigger:disabled {
  cursor: wait;
  opacity: 0.65;
}

.date-range-field__summary {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.date-range-field__chevron {
  color: var(--color-muted);
  font-size: 12px;
}

.date-range-field__popover {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  z-index: 20;
  display: grid;
  gap: 10px;
  width: 320px;
  padding: 12px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  box-shadow: var(--shadow-soft);
}

.date-range-field__quick-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.date-range-field__quick-button,
.date-range-field__nav {
  min-height: 30px;
  padding: 0 10px;
  border: 0;
  border-radius: 10px;
  background: var(--color-surface-subtle);
  color: var(--color-text);
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}

.date-range-field__quick-button:hover,
.date-range-field__nav:hover {
  background: var(--color-surface-muted);
}

.date-range-field__current-range {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--color-muted);
  font-size: 13px;
  font-weight: 600;
}

.date-range-field__range-separator {
  color: var(--color-text);
}

.date-range-field__calendar {
  display: grid;
  gap: 8px;
}

.date-range-field__calendar-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.date-range-field__calendar-header strong {
  font-size: 14px;
  text-transform: capitalize;
}

.date-range-field__weekdays,
.date-range-field__days {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: 4px;
}

.date-range-field__weekdays span {
  color: var(--color-muted);
  font-size: 11px;
  font-weight: 700;
  text-align: center;
}

.date-range-field__day {
  min-height: 34px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--color-text);
  cursor: pointer;
}

.date-range-field__day:hover {
  background: var(--color-surface-subtle);
}

.date-range-field__day--muted {
  color: #9aa4b2;
}

.date-range-field__day--selected {
  background: var(--color-text);
  color: #fff;
}

.date-range-field__day--range {
  background: var(--color-surface-muted);
}
</style>
