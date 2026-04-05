export type NavigationItem = {
  name: string;
  label: string;
  to: string;
};

export const navigationItems: NavigationItem[] = [
  { name: 'dashboard', label: 'Dashboard', to: '/' },
  { name: 'leads', label: 'Leads', to: '/leads' },
  { name: 'branches', label: 'Branches', to: '/branches' },
  { name: 'birthday-packages', label: 'Birthday Packages', to: '/birthday-packages' },
  { name: 'tariffs', label: 'Tariffs', to: '/tariffs' },
  { name: 'promotions', label: 'Promotions', to: '/promotions' },
  { name: 'content', label: 'Content', to: '/content' },
  { name: 'gallery', label: 'Gallery', to: '/gallery' },
  { name: 'faq', label: 'FAQ', to: '/faq' },
  { name: 'customers', label: 'Customers', to: '/customers' },
  { name: 'push-campaigns', label: 'Push Campaigns', to: '/push-campaigns' },
  { name: 'audit-logs', label: 'Audit Logs', to: '/audit-logs' }
];

