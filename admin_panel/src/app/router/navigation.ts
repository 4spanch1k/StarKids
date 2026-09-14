import type { AdminRole } from '@/features/auth/types';

export type NavigationItem = {
  name: string;
  label: string;
  to: string;
  allowedRoles?: AdminRole[];
};

export const primaryNavigationItems: NavigationItem[] = [
  { name: 'leads', label: 'Заявки', to: '/leads' },
  { name: 'branches', label: 'Филиалы', to: '/branches' },
  { name: 'birthday-packages', label: 'Пакеты дней рождения', to: '/birthday-packages' },
  {
    name: 'promotions',
    label: 'Акции',
    to: '/promotions',
    allowedRoles: ['super_admin', 'content_manager'],
  },
  {
    name: 'news',
    label: 'Новости',
    to: '/news',
    allowedRoles: ['super_admin', 'content_manager'],
  },
  {
    name: 'content',
    label: 'Контент',
    to: '/content',
    allowedRoles: ['super_admin', 'content_manager'],
  },
  {
    name: 'gallery',
    label: 'Галерея',
    to: '/gallery',
    allowedRoles: ['super_admin', 'content_manager'],
  },
  {
    name: 'faq',
    label: 'Частые вопросы',
    to: '/faq',
    allowedRoles: ['super_admin', 'content_manager'],
  },
];

export const secondaryNavigationItems: NavigationItem[] = [
  { name: 'dashboard', label: 'Сводка', to: '/dashboard', allowedRoles: ['super_admin'] },
  { name: 'menu', label: 'Меню', to: '/menu' },
  { name: 'tickets', label: 'Билеты', to: '/tickets' },
  {
    name: 'ticket-scanner',
    label: 'Сканер билетов',
    to: '/ticket-scanner',
    allowedRoles: ['operator', 'super_admin'],
  },
  {
    name: 'customers',
    label: 'Клиенты',
    to: '/customers',
    allowedRoles: ['super_admin'],
  },
  {
    name: 'staff',
    label: 'Сотрудники',
    to: '/staff',
    allowedRoles: ['super_admin'],
  },
  {
    name: 'push-campaigns',
    label: 'Пуш-кампании',
    to: '/push-campaigns',
    allowedRoles: ['super_admin', 'content_manager'],
  },
  { name: 'audit-logs', label: 'Журнал аудита', to: '/audit-logs' },
  { name: 'loyalty', label: 'Лояльность', to: '/loyalty', allowedRoles: ['super_admin'] },
];

export const navigationItems: NavigationItem[] = [
  ...primaryNavigationItems,
  ...secondaryNavigationItems,
];
