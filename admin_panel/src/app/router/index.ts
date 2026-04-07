import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router';

import AdminLayout from '@/app/layouts/AdminLayout.vue';
import AuditLogsPage from '@/pages/audit-logs/AuditLogsPage.vue';
import BirthdayPackagesPage from '@/pages/birthday-packages/BirthdayPackagesPage.vue';
import BranchesPage from '@/pages/branches/BranchesPage.vue';
import ContentPage from '@/pages/content/ContentPage.vue';
import CustomersPage from '@/pages/customers/CustomersPage.vue';
import DashboardPage from '@/pages/dashboard/DashboardPage.vue';
import FAQPage from '@/pages/faq/FAQPage.vue';
import GalleryPage from '@/pages/gallery/GalleryPage.vue';
import LeadsPage from '@/pages/leads/LeadsPage.vue';
import LoginPage from '@/pages/login/LoginPage.vue';
import PromotionsPage from '@/pages/promotions/PromotionsPage.vue';
import PushCampaignsPage from '@/pages/push-campaigns/PushCampaignsPage.vue';
import TariffsPage from '@/pages/tariffs/TariffsPage.vue';
import { useSessionStore } from '@/features/auth/stores/useSessionStore';

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'login',
    component: LoginPage,
    meta: {
      guestOnly: true,
    },
  },
  {
    path: '/',
    component: AdminLayout,
    meta: {
      requiresAuth: true,
    },
    children: [
      { path: '', redirect: { name: 'leads' } },
      { path: 'dashboard', name: 'dashboard', component: DashboardPage },
      { path: 'leads', name: 'leads', component: LeadsPage },
      { path: 'branches', name: 'branches', component: BranchesPage },
      {
        path: 'birthday-packages',
        name: 'birthday-packages',
        component: BirthdayPackagesPage,
      },
      { path: 'tariffs', name: 'tariffs', component: TariffsPage },
      { path: 'promotions', name: 'promotions', component: PromotionsPage },
      { path: 'content', name: 'content', component: ContentPage },
      { path: 'gallery', name: 'gallery', component: GalleryPage },
      { path: 'faq', name: 'faq', component: FAQPage },
      { path: 'customers', name: 'customers', component: CustomersPage },
      {
        path: 'push-campaigns',
        name: 'push-campaigns',
        component: PushCampaignsPage,
      },
      { path: 'audit-logs', name: 'audit-logs', component: AuditLogsPage },
    ],
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.beforeEach(async (to) => {
  const sessionStore = useSessionStore();
  await sessionStore.initialize();

  const requiresAuth = to.matched.some((record) => record.meta.requiresAuth);
  const guestOnly = to.matched.some((record) => record.meta.guestOnly);

  if (requiresAuth && !sessionStore.isAuthenticated) {
    return {
      name: 'login',
      query: { redirect: to.fullPath },
    };
  }

  if (guestOnly && sessionStore.isAuthenticated) {
    const redirectPath =
      typeof to.query.redirect === 'string' && to.query.redirect !== '/login'
        ? to.query.redirect
        : '/';
    return redirectPath;
  }

  return true;
});

export default router;
