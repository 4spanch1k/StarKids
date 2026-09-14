const SURFACE_LABELS: Record<string, string> = {
  birthdays: 'Дни рождения',
  contacts: 'Контакты и маршрут',
  home: 'Главный экран',
  prices_rules: 'Меню',
  promotions: 'Акции',
  request: 'Форма заявки',
};

const SUPPORTED_SURFACES = ['birthdays', 'contacts', 'promotions'] as const;

export const contentSurfaceOptions = SUPPORTED_SURFACES.map((value) => ({
  value,
  label: SURFACE_LABELS[value],
}));

export function getContentSurfaceLabel(surface: string): string {
  if (SURFACE_LABELS[surface]) {
    return SURFACE_LABELS[surface];
  }

  return surface.split('_').join(' ');
}
