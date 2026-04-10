<template>
  <label ref="rootRef" class="admin-field app-select">
    <span class="admin-field__label">{{ label }}</span>

    <button
      type="button"
      class="app-select__trigger"
      :class="{ 'app-select__trigger--open': isOpen }"
      :disabled="disabled"
      @click="toggleOpen"
    >
      <span class="app-select__value">{{ selectedLabel }}</span>
      <span class="app-select__chevron" aria-hidden="true">▾</span>
    </button>

    <div v-if="isOpen" class="app-select__menu">
      <button
        v-for="option in options"
        :key="option.value"
        type="button"
        class="app-select__option"
        :class="{ 'app-select__option--active': option.value === modelValue }"
        @click="selectOption(option.value)"
      >
        {{ option.label }}
      </button>
    </div>
  </label>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';

type SelectOption = {
  label: string;
  value: string;
};

const props = withDefaults(
  defineProps<{
    label: string;
    modelValue: string;
    options: SelectOption[];
    placeholder?: string;
    disabled?: boolean;
  }>(),
  {
    placeholder: 'Выберите значение',
    disabled: false,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

const isOpen = ref(false);
const rootRef = ref<HTMLElement | null>(null);

const selectedLabel = computed(() => {
  const selectedOption = props.options.find((option) => option.value === props.modelValue);
  return selectedOption?.label ?? props.placeholder;
});

function toggleOpen() {
  if (props.disabled) {
    return;
  }

  isOpen.value = !isOpen.value;
}

function selectOption(value: string) {
  emit('update:modelValue', value);
  isOpen.value = false;
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

onMounted(() => {
  document.addEventListener('mousedown', handleDocumentClick);
});

onBeforeUnmount(() => {
  document.removeEventListener('mousedown', handleDocumentClick);
});
</script>

<style scoped>
.app-select {
  position: relative;
}

.app-select__trigger {
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
  cursor: pointer;
  transition:
    border-color 120ms ease,
    box-shadow 120ms ease,
    background-color 120ms ease;
}

.app-select__trigger:hover:not(:disabled),
.app-select__trigger--open {
  border-color: var(--color-border-strong);
  box-shadow: 0 0 0 2px rgba(208, 47, 112, 0.08);
}

.app-select__trigger:disabled {
  cursor: wait;
  opacity: 0.65;
}

.app-select__value {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.app-select__chevron {
  color: var(--color-muted);
  font-size: 12px;
}

.app-select__menu {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  right: 0;
  z-index: 20;
  display: grid;
  gap: 4px;
  padding: 6px;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-surface);
  box-shadow: var(--shadow-soft);
}

.app-select__option {
  min-height: 36px;
  padding: 0 10px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--color-text);
  text-align: left;
  cursor: pointer;
}

.app-select__option:hover,
.app-select__option--active {
  background: var(--color-surface-subtle);
}

.app-select__option--active {
  color: var(--color-accent);
  font-weight: 700;
}
</style>
