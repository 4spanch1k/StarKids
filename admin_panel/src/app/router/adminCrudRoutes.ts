import type { Component } from 'vue';
import type { RouteRecordRaw } from 'vue-router';

export type AdminCrudRouteGroup = {
  list: string;
  detail?: string;
  create?: string;
  edit?: string;
  idParam?: string;
};

type AdminCrudRouteOptions = {
  path: string;
  name: string;
  component: Component;
  idParam: string;
  allowCreate?: boolean;
  allowEdit?: boolean;
  allowDetail?: boolean;
};

export function buildAdminCrudRouteGroup(
  options: AdminCrudRouteOptions,
): { routes: RouteRecordRaw[]; names: AdminCrudRouteGroup } {
  const allowCreate = options.allowCreate ?? true;
  const allowEdit = options.allowEdit ?? true;
  const allowDetail = options.allowDetail ?? true;

  const names: AdminCrudRouteGroup = {
    list: options.name,
    idParam: options.idParam,
  };

  const routes: RouteRecordRaw[] = [
    {
      path: options.path,
      name: names.list,
      component: options.component,
    },
  ];

  if (allowCreate) {
    names.create = `${options.name}-create`;
    routes.push({
      path: `${options.path}/new`,
      name: names.create,
      component: options.component,
    });
  }

  if (allowDetail) {
    names.detail = `${options.name}-detail`;
    routes.push({
      path: `${options.path}/:${options.idParam}`,
      name: names.detail,
      component: options.component,
    });
  }

  if (allowEdit) {
    names.edit = `${options.name}-edit`;
    routes.push({
      path: `${options.path}/:${options.idParam}/edit`,
      name: names.edit,
      component: options.component,
    });
  }

  return { routes, names };
}

export const adminCrudRouteNames = {
  leads: {
    list: 'leads',
    detail: 'leads-detail',
    idParam: 'leadId',
  },
  branches: {
    list: 'branches',
    detail: 'branches-detail',
    create: 'branches-create',
    edit: 'branches-edit',
    idParam: 'branchId',
  },
  birthdayPackages: {
    list: 'birthday-packages',
    detail: 'birthday-packages-detail',
    create: 'birthday-packages-create',
    edit: 'birthday-packages-edit',
    idParam: 'packageId',
  },
  promotions: {
    list: 'promotions',
    detail: 'promotions-detail',
    create: 'promotions-create',
    edit: 'promotions-edit',
    idParam: 'promotionId',
  },
  content: {
    list: 'content',
    detail: 'content-detail',
    create: 'content-create',
    edit: 'content-edit',
    idParam: 'blockId',
  },
  gallery: {
    list: 'gallery',
    detail: 'gallery-detail',
    edit: 'gallery-edit',
    idParam: 'branchId',
  },
  faq: {
    list: 'faq',
    detail: 'faq-detail',
    create: 'faq-create',
    edit: 'faq-edit',
    idParam: 'faqId',
  },
  menu: {
    list: 'menu',
    detail: 'menu-detail',
    edit: 'menu-edit',
    idParam: 'branchId',
  },
  tickets: {
    list: 'tickets',
    detail: 'tickets-detail',
    edit: 'tickets-edit',
    idParam: 'branchId',
  },
} as const;
