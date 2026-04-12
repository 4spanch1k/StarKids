export type NavigationItem = {
  name: string;
  label: string;
  to: string;
};

export const primaryNavigationItems: NavigationItem[] = [
  { name: 'leads', label: 'Заявки', to: '/leads' },
  { name: 'branches', label: 'Филиалы', to: '/branches' },
  { name: 'birthday-packages', label: 'Пакеты дней рождения', to: '/birthday-packages' },
  { name: 'promotions', label: 'Акции', to: '/promotions' },
  { name: 'content', label: 'Контент', to: '/content' },
  { name: 'gallery', label: 'Галерея', to: '/gallery' },
  { name: 'faq', label: 'Частые вопросы', to: '/faq' },
];

export const secondaryNavigationItems: NavigationItem[] = [
  { name: 'dashboard', label: 'Сводка', to: '/dashboard' },
  { name: 'menu', label: 'Меню', to: '/menu' },
  { name: 'tickets', label: 'Билеты', to: '/tickets' },
  { name: 'customers', label: 'Клиенты', to: '/customers' },
  { name: 'push-campaigns', label: 'Пуш-кампании', to: '/push-campaigns' },
  { name: 'audit-logs', label: 'Журнал аудита', to: '/audit-logs' },
];

export const navigationItems: NavigationItem[] = [
  ...primaryNavigationItems,
  ...secondaryNavigationItems,
];
