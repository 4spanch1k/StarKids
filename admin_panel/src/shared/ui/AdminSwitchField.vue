<template>
  <label class="admin-switch-field">
    <input
      :checked="modelValue"
      type="checkbox"
      class="admin-switch-field__input"
      :disabled="disabled"
      @change="handleChange"
    />
    <span class="admin-switch-field__control" aria-hidden="true"></span>
    <span class="admin-switch-field__copy">
      <strong>{{ label }}</strong>
      <span v-if="hint">{{ hint }}</span>
    </span>
  </label>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    modelValue: boolean;
    label: string;
    hint?: string;
    disabled?: boolean;
  }>(),
  {
    hint: '',
    disabled: false,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

function handleChange(event: Event) {
  const target = event.target as HTMLInputElement;
  emit('update:modelValue', target.checked);
}
</script>

<style scoped>
.admin-switch-field {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
}

.admin-switch-field__input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.admin-switch-field__control {
  position: relative;
  flex: 0 0 auto;
  width: 42px;
  height: 24px;
  border-radius: 999px;
  background: var(--color-surface-muted);
  transition: background-color 120ms ease;
}

.admin-switch-field__control::after {
  content: '';
  position: absolute;
  top: 3px;
  left: 3px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.12);
  transition: transform 120ms ease;
}

.admin-switch-field__input:checked + .admin-switch-field__control {
  background: var(--color-accent);
}

.admin-switch-field__input:checked + .admin-switch-field__control::after {
  transform: translateX(18px);
}

.admin-switch-field__copy {
  display: grid;
  gap: 2px;
}

.admin-switch-field__copy strong,
.admin-switch-field__copy span {
  line-height: 1.4;
}

.admin-switch-field__copy strong {
  font-size: 14px;
}

.admin-switch-field__copy span {
  color: var(--color-muted);
  font-size: 13px;
}
</style>
