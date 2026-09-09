const SURFACE_LABELS: Record<string, string> = {
  birthdays: 'Дни рождения',
  contacts: 'Контакты и маршрут',
  home: 'Главный экран',
  prices_rules: 'Меню',
  promotions: 'Акции',
  request: 'Форма заявки',
};

export const contentSurfaceOptions = Object.entries(SURFACE_LABELS).map(([value, label]) => ({
  value,
  label,
}));

export function getContentSurfaceLabel(surface: string): string {
  if (SURFACE_LABELS[surface]) {
    return SURFACE_LABELS[surface];
  }

  return surface.split('_').join(' ');
}
