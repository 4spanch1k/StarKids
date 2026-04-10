import { nextTick } from 'vue';

import type { AdminFieldErrors } from '@/shared/lib/adminApiErrors';

const phonePattern = /^\+?[0-9()\- ]{10,20}$/;

export function replaceFieldErrors(
  target: AdminFieldErrors,
  nextErrors: AdminFieldErrors,
): void {
  for (const key of Object.keys(target)) {
    delete target[key];
  }

  for (const [key, value] of Object.entries(nextErrors)) {
    if (value) {
      target[key] = value;
    }
  }
}

export function clearFieldError(
  target: AdminFieldErrors,
  field: string,
): void {
  if (target[field]) {
    delete target[field];
  }
}

export function hasFieldErrors(errors: AdminFieldErrors): boolean {
  return Object.keys(errors).length > 0;
}

export async function focusFirstFieldError(
  formElement: HTMLFormElement | null,
  errors: AdminFieldErrors,
): Promise<void> {
  const firstField = Object.keys(errors)[0];
  if (!firstField || !formElement) {
    return;
  }

  await nextTick();

  const fieldControl = formElement.querySelector<HTMLElement>(
    `[data-field="${firstField}"] .admin-control, ` +
      `[data-field="${firstField}"] .app-select__trigger, ` +
      `[data-field="${firstField}"] textarea, ` +
      `[data-field="${firstField}"] input, ` +
      `[data-field="${firstField}"] button`,
  );

  fieldControl?.scrollIntoView({
    behavior: 'smooth',
    block: 'center',
  });
  fieldControl?.focus();
}

export function validateRequiredText(
  value: string,
  message: string,
  minLength = 1,
): string {
  const trimmedValue = value.trim();
  if (!trimmedValue) {
    return message;
  }

  if (trimmedValue.length < minLength) {
    return message;
  }

  return '';
}

export function validateOptionalText(
  value: string,
  message: string,
  minLength = 1,
): string {
  const trimmedValue = value.trim();
  if (!trimmedValue) {
    return '';
  }

  if (trimmedValue.length < minLength) {
    return message;
  }

  return '';
}

export function validateRequiredPhone(
  value: string,
  missingMessage: string,
  invalidMessage: string,
): string {
  const trimmedValue = value.trim();
  if (!trimmedValue) {
    return missingMessage;
  }

  if (!phonePattern.test(trimmedValue)) {
    return invalidMessage;
  }

  return '';
}

export function validateRequiredUrl(
  value: string,
  missingMessage: string,
  invalidMessage: string,
): string {
  const trimmedValue = value.trim();
  if (!trimmedValue) {
    return missingMessage;
  }

  if (!isValidHttpUrl(trimmedValue)) {
    return invalidMessage;
  }

  return '';
}

export function validateOptionalUrl(
  value: string,
  invalidMessage: string,
): string {
  const trimmedValue = value.trim();
  if (!trimmedValue) {
    return '';
  }

  if (!isValidHttpUrl(trimmedValue)) {
    return invalidMessage;
  }

  return '';
}

export function validateNonNegativeNumber(
  value: number,
  message: string,
): string {
  if (!Number.isFinite(value) || value < 0) {
    return message;
  }

  return '';
}

function isValidHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}
