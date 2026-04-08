export type AdminStatusTone =
  | 'neutral'
  | 'new'
  | 'in-progress'
  | 'closed'
  | 'warning'
  | 'danger';

export function resolveActiveStatus(isActive: boolean): {
  label: string;
  tone: AdminStatusTone;
} {
  return isActive
    ? { label: 'Активен', tone: 'closed' }
    : { label: 'Неактивен', tone: 'neutral' };
}

export function resolvePublicationStatus({
  isActive,
  isPublished,
}: {
  isActive: boolean;
  isPublished: boolean;
}): {
  label: string;
  tone: AdminStatusTone;
} {
  if (!isActive) {
    return {
      label: 'Выключено',
      tone: 'neutral',
    };
  }

  if (isPublished) {
    return {
      label: 'Опубликовано',
      tone: 'closed',
    };
  }

  return {
    label: 'Черновик',
    tone: 'warning',
  };
}
