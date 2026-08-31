import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router';

import AdminLayout from '@/app/layouts/AdminLayout.vue';
import {
  adminCrudRouteNames,
  buildAdminCrudRouteGroup,
} from '@/app/router/adminCrudRoutes';
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
import MenuPage from '@/pages/menu/MenuPage.vue';
import NewsPage from '@/pages/news/NewsPage.vue';
import PromotionsPage from '@/pages/promotions/PromotionsPage.vue';
import PushCampaignsPage from '@/pages/push-campaigns/PushCampaignsPage.vue';
import TicketsPage from '@/pages/tickets/TicketsPage.vue';
import TicketScannerPage from '@/pages/ticket-scanner/TicketScannerPage.vue';
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
      ...buildAdminCrudRouteGroup({
        path: 'leads',
        name: adminCrudRouteNames.leads.list,
        component: LeadsPage,
        idParam: adminCrudRouteNames.leads.idParam,
        allowCreate: false,
        allowEdit: false,
      }).routes,
      ...buildAdminCrudRouteGroup({
        path: 'branches',
        name: adminCrudRouteNames.branches.list,
        component: BranchesPage,
        idParam: adminCrudRouteNames.branches.idParam,
      }).routes,
      ...buildAdminCrudRouteGroup({
        path: 'birthday-packages',
        name: adminCrudRouteNames.birthdayPackages.list,
        component: BirthdayPackagesPage,
        idParam: adminCrudRouteNames.birthdayPackages.idParam,
      }).routes,
      ...buildAdminCrudRouteGroup({
        path: 'menu',
        name: adminCrudRouteNames.menu.list,
        component: MenuPage,
        idParam: adminCrudRouteNames.menu.idParam,
        allowCreate: false,
      }).routes,
      ...buildAdminCrudRouteGroup({
        path: 'tickets',
        name: adminCrudRouteNames.tickets.list,
        component: TicketsPage,
        idParam: adminCrudRouteNames.tickets.idParam,
        allowCreate: false,
      }).routes,
      {
        path: 'ticket-scanner',
        name: 'ticket-scanner',
        component: TicketScannerPage,
        meta: {
          allowedRoles: ['super_admin', 'operator'],
        },
      },
      ...buildAdminCrudRouteGroup({
        path: 'promotions',
        name: adminCrudRouteNames.promotions.list,
        component: PromotionsPage,
        idParam: adminCrudRouteNames.promotions.idParam,
      }).routes,
      ...buildAdminCrudRouteGroup({
        path: 'news',
        name: adminCrudRouteNames.news.list,
        component: NewsPage,
        idParam: adminCrudRouteNames.news.idParam,
      }).routes,
      ...buildAdminCrudRouteGroup({
        path: 'content',
        name: adminCrudRouteNames.content.list,
        component: ContentPage,
        idParam: adminCrudRouteNames.content.idParam,
      }).routes,
      ...buildAdminCrudRouteGroup({
        path: 'gallery',
        name: adminCrudRouteNames.gallery.list,
        component: GalleryPage,
        idParam: adminCrudRouteNames.gallery.idParam,
        allowCreate: false,
      }).routes,
      ...buildAdminCrudRouteGroup({
        path: 'faq',
        name: adminCrudRouteNames.faq.list,
        component: FAQPage,
        idParam: adminCrudRouteNames.faq.idParam,
      }).routes,
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

  const allowedRoles = to.matched
    .map((record) => record.meta.allowedRoles)
    .find((roles): roles is string[] => Array.isArray(roles));
  if (allowedRoles && !allowedRoles.includes(sessionStore.operatorRole)) {
    return { name: 'leads' };
  }

  return true;
});

export default router;
