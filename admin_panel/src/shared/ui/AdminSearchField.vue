<template>
  <label class="admin-field admin-search-field">
    <span v-if="label" class="admin-field__label">{{ label }}</span>
    <span class="admin-search-field__icon" aria-hidden="true">
      <svg viewBox="0 0 20 20" focusable="false">
        <path
          d="M13.5 12.1l3.6 3.6-1.4 1.4-3.6-3.6a6 6 0 1 1 1.4-1.4zM8.5 13A4.5 4.5 0 1 0 8.5 4a4.5 4.5 0 0 0 0 9z"
          fill="currentColor"
        />
      </svg>
    </span>
    <input
      :value="modelValue"
      type="search"
      class="admin-control admin-search-field__input"
      :placeholder="placeholder"
      :disabled="disabled"
      @input="handleInput"
    />
  </label>
</template>

<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    label?: string;
    modelValue: string;
    placeholder?: string;
    disabled?: boolean;
  }>(),
  {
    label: 'Поиск',
    placeholder: 'Найти запись',
    disabled: false,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

function handleInput(event: Event) {
  const target = event.target as HTMLInputElement;
  emit('update:modelValue', target.value);
}
</script>

<style scoped>
.admin-search-field {
  position: relative;
}

.admin-search-field__icon {
  position: absolute;
  left: 12px;
  bottom: 11px;
  display: inline-flex;
  width: 16px;
  height: 16px;
  color: var(--color-muted);
  pointer-events: none;
}

.admin-search-field__icon svg {
  width: 16px;
  height: 16px;
}

.admin-search-field__input {
  padding-left: 38px;
}
</style>
