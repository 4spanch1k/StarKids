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

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'login',
    component: LoginPage,
  },
  {
    path: '/',
    component: AdminLayout,
    children: [
      { path: '', name: 'dashboard', component: DashboardPage },
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

export default router;

