import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { useAdminViewport } from '@/shared/composables/useAdminViewport';

type RouteStateOptions = {
  listRouteName: string;
  detailRouteName?: string;
  createRouteName?: string;
  editRouteName?: string;
  idParam: string;
};

export type AdminCrudMode = 'list' | 'detail' | 'create' | 'edit';

export function useAdminCrudRouteState(options: RouteStateOptions) {
  const route = useRoute();
  const router = useRouter();
  const viewport = useAdminViewport();

  const currentRouteName = computed(() => {
    return typeof route.name === 'string' ? route.name : '';
  });

  const activeId = computed(() => {
    const value = route.params[options.idParam];
    return typeof value === 'string' ? value : '';
  });

  const mode = computed<AdminCrudMode>(() => {
    if (options.createRouteName && currentRouteName.value === options.createRouteName) {
      return 'create';
    }

    if (options.editRouteName && currentRouteName.value === options.editRouteName) {
      return 'edit';
    }

    if (options.detailRouteName && currentRouteName.value === options.detailRouteName) {
      return 'detail';
    }

    return 'list';
  });

  const showInlineDetail = computed(() => {
    return viewport.isDesktop.value && Boolean(activeId.value) && (mode.value === 'detail' || mode.value === 'edit');
  });

  const showDetailRoutePanel = computed(() => {
    return !viewport.isDesktop.value && mode.value === 'detail' && Boolean(activeId.value);
  });

  const showEditorRoutePanel = computed(() => {
    return mode.value === 'create' || mode.value === 'edit';
  });

  async function goToList() {
    await router.push({ name: options.listRouteName });
  }

  async function goToDetail(id: string) {
    if (!options.detailRouteName) {
      return;
    }

    await router.push({
      name: options.detailRouteName,
      params: { [options.idParam]: id },
    });
  }

  async function goToCreate() {
    if (!options.createRouteName) {
      return;
    }

    await router.push({ name: options.createRouteName });
  }

  async function goToEdit(id: string) {
    if (!options.editRouteName) {
      return;
    }

    await router.push({
      name: options.editRouteName,
      params: { [options.idParam]: id },
    });
  }

  async function closeDetail() {
    await goToList();
  }

  async function closeEditor() {
    if (mode.value === 'edit' && activeId.value && options.detailRouteName) {
      await router.push({
        name: options.detailRouteName,
        params: { [options.idParam]: activeId.value },
      });
      return;
    }

    await goToList();
  }

  return {
    activeId,
    mode,
    isMobile: viewport.isMobile,
    isTablet: viewport.isTablet,
    isDesktop: viewport.isDesktop,
    showInlineDetail,
    showDetailRoutePanel,
    showEditorRoutePanel,
    goToList,
    goToDetail,
    goToCreate,
    goToEdit,
    closeDetail,
    closeEditor,
  };
}
