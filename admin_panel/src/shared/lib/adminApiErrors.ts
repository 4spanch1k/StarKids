import { HttpError } from '@/shared/api/httpClient';

export type AdminFieldErrors = Record<string, string>;

type ErrorDetail = {
  field?: unknown;
  message?: unknown;
};

type ErrorEnvelope = {
  code?: unknown;
  message?: unknown;
  details?: unknown;
};

const errorCodeMessages: Record<string, string> = {
  authentication_required: 'Сессия истекла. Войдите снова.',
  authorization_required: 'У вас нет доступа к этому разделу.',
  validation_error: 'Проверьте обязательные поля.',
  branch_slug_taken: 'Такой служебный код уже используется.',
  branch_not_found: 'Выберите существующий филиал.',
  branch_prices_rules_not_found: 'Профиль цен для этого филиала еще не создан.',
  content_block_key_taken: 'Для этой поверхности уже есть блок с таким ключом.',
  promotion_not_found: 'Акция не найдена.',
  content_block_not_found: 'Контентный блок не найден.',
  faq_not_found: 'Вопрос не найден.',
};

const rawMessageMap: Record<string, string> = {
  'Request validation failed.': 'Проверьте обязательные поля.',
  'Input should be a valid dictionary or object to extract fields from':
    'Не удалось отправить форму. Обновите страницу и попробуйте снова.',
  'Branch slug is already in use.': 'Такой служебный код уже используется.',
  'Content block key is already in use for this surface.':
    'Для этой поверхности уже есть блок с таким ключом.',
  'Branch was not found.': 'Филиал не найден.',
  'Promotion was not found.': 'Акция не найдена.',
  'Content block was not found.': 'Контентный блок не найден.',
  'FAQ entry was not found.': 'Вопрос не найден.',
  'Invalid email or password.': 'Проверьте email и пароль.',
  'Authentication required.': 'Сессия истекла. Войдите снова.',
  'You do not have access to this resource.': 'У вас нет доступа к этому разделу.',
  'JWT secret key is not configured.': 'Сервер настроен некорректно. Попробуйте позже.',
};

const requiredFieldMessages: Record<string, string> = {
  slug: 'Введите служебный код.',
  name: 'Введите название.',
  city: 'Введите город.',
  address: 'Введите адрес.',
  shortLabel: 'Введите короткую подпись.',
  workingHours: 'Введите режим работы.',
  description: 'Добавьте описание.',
  phone: 'Введите номер телефона.',
  whatsappPhone: 'Введите номер WhatsApp.',
  mapUrl: 'Добавьте ссылку на карту.',
  routeLabel: 'Введите подпись маршрута.',
  title: 'Введите заголовок.',
  ctaLabel: 'Введите текст кнопки.',
  key: 'Введите ключ блока.',
  question: 'Введите вопрос.',
  answer: 'Введите ответ.',
  branchId: 'Выберите филиал.',
  priceLabel: 'Введите подпись цены.',
  guestCapacityLabel: 'Введите вместимость.',
  introTitle: 'Введите заголовок.',
  introDescription: 'Добавьте описание.',
  birthdayNote: 'Добавьте блок про день рождения.',
  surface: 'Выберите поверхность.',
};

export function resolveAdminApiErrorMessage(
  error: unknown,
  fallbackMessage: string,
): string {
  if (error instanceof HttpError) {
    const code = extractErrorCode(error.payload);
    if (code && errorCodeMessages[code]) {
      return errorCodeMessages[code];
    }

    const payloadMessage = extractPayloadMessage(error.payload);
    if (payloadMessage) {
      return translateMessage(payloadMessage, fallbackMessage);
    }

    return error.status >= 500
      ? 'Не удалось сохранить изменения. Попробуйте позже.'
      : fallbackMessage;
  }

  if (error instanceof Error && error.message) {
    return translateMessage(error.message, fallbackMessage);
  }

  return fallbackMessage;
}

export function resolveAdminApiFieldErrors(error: unknown): AdminFieldErrors {
  if (!(error instanceof HttpError)) {
    return {};
  }

  const detailErrors = extractDetailErrors(error.payload);
  if (detailErrors.length > 0) {
    return detailErrors.reduce<AdminFieldErrors>((accumulator, detail) => {
      const field = normalizeFieldKey(detail.field);
      const message = localizeFieldMessage(field, detail.message);
      if (field && message && !accumulator[field]) {
        accumulator[field] = message;
      }
      return accumulator;
    }, {});
  }

  const groupedErrors = extractGroupedErrors(error.payload);
  return Object.entries(groupedErrors).reduce<AdminFieldErrors>((accumulator, [field, messages]) => {
    const firstMessage = messages.find(Boolean);
    if (!firstMessage) {
      return accumulator;
    }

    const normalizedField = normalizeFieldKey(field);
    accumulator[normalizedField] = localizeFieldMessage(normalizedField, firstMessage);
    return accumulator;
  }, {});
}

function extractErrorCode(payload: unknown): string {
  const envelope = extractErrorEnvelope(payload);
  return typeof envelope?.code === 'string' ? envelope.code : '';
}

function extractPayloadMessage(payload: unknown): string {
  const envelope = extractErrorEnvelope(payload);
  if (typeof envelope?.message === 'string') {
    return envelope.message;
  }

  if (isRecord(payload) && typeof payload.message === 'string') {
    return payload.message;
  }

  return '';
}

function extractDetailErrors(payload: unknown): ErrorDetail[] {
  const envelope = extractErrorEnvelope(payload);
  if (!Array.isArray(envelope?.details)) {
    return [];
  }

  return envelope.details.filter((item): item is ErrorDetail => isRecord(item));
}

function extractGroupedErrors(payload: unknown): Record<string, string[]> {
  if (!isRecord(payload) || !isRecord(payload.errors)) {
    return {};
  }

  return Object.entries(payload.errors).reduce<Record<string, string[]>>((accumulator, [field, value]) => {
    if (Array.isArray(value)) {
      accumulator[field] = value.filter((item): item is string => typeof item === 'string');
      return accumulator;
    }

    if (typeof value === 'string') {
      accumulator[field] = [value];
    }

    return accumulator;
  }, {});
}

function extractErrorEnvelope(payload: unknown): ErrorEnvelope | null {
  if (!isRecord(payload) || !isRecord(payload.error)) {
    return null;
  }

  return payload.error as ErrorEnvelope;
}

function normalizeFieldKey(value: unknown): string {
  if (typeof value !== 'string' || !value.trim()) {
    return '';
  }

  const leaf = value
    .split('.')
    .filter(Boolean);

  const normalizedLeaf = leaf[leaf.length - 1] ?? value;

  return normalizedLeaf.replace(/_([a-z])/g, (_match: string, char: string) => {
    return char.toUpperCase();
  });
}

function localizeFieldMessage(field: string, rawMessage: unknown): string {
  if (typeof rawMessage !== 'string' || !rawMessage.trim()) {
    return requiredFieldMessages[field] ?? 'Проверьте значение поля.';
  }

  if (containsCyrillic(rawMessage)) {
    return rawMessage;
  }

  if (rawMessageMap[rawMessage]) {
    return rawMessageMap[rawMessage];
  }

  if (rawMessage === 'Field required') {
    return requiredFieldMessages[field] ?? 'Заполните обязательное поле.';
  }

  if (/valid dictionary or object to extract fields from/i.test(rawMessage)) {
    return 'Не удалось отправить форму. Обновите страницу и попробуйте снова.';
  }

  if (/at least (\d+) characters?/i.test(rawMessage)) {
    const match = rawMessage.match(/at least (\d+) characters?/i);
    const minLength = match?.[1];
    return minLength
      ? `Введите не меньше ${minLength} символов.`
      : 'Введите более длинное значение.';
  }

  if (/at most (\d+) characters?/i.test(rawMessage)) {
    const match = rawMessage.match(/at most (\d+) characters?/i);
    const maxLength = match?.[1];
    return maxLength
      ? `Сократите значение до ${maxLength} символов.`
      : 'Сократите значение.';
  }

  if (/pattern/i.test(rawMessage)) {
    if (field.toLowerCase().includes('phone')) {
      return 'Введите корректный номер телефона.';
    }

    if (field.toLowerCase().includes('url')) {
      return 'Введите корректную ссылку.';
    }

    return 'Введите корректное значение.';
  }

  if (/greater than or equal to 0/i.test(rawMessage)) {
    return 'Введите значение не меньше 0.';
  }

  return 'Проверьте значение поля.';
}

function translateMessage(rawMessage: string, fallbackMessage: string): string {
  if (rawMessageMap[rawMessage]) {
    return rawMessageMap[rawMessage];
  }

  if (containsCyrillic(rawMessage)) {
    return rawMessage;
  }

  if (/^Branch .+ was not found\.$/.test(rawMessage)) {
    return 'Выберите существующий филиал.';
  }

  return fallbackMessage;
}

function containsCyrillic(value: string): boolean {
  return /[А-Яа-яЁё]/.test(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}
