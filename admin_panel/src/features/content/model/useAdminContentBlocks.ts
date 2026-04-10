import { computed, reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import {
  createAdminContentBlock,
  getAdminContentBlock,
  listAdminContentBlocks,
  updateAdminContentBlock,
} from '@/features/content/api/adminContentApi';
import type {
  AdminContentBlock,
  AdminContentBlockCreatePayload,
  AdminContentBlockUpdatePayload,
} from '@/features/content/model/adminContent';

type ToggleFilter = 'all' | 'yes' | 'no';

const defaultForm = (): AdminContentBlockCreatePayload => ({
  surface: 'home',
  key: '',
  title: '',
  body: '',
  ctaLabel: '',
  displayOrder: 0,
  isActive: true,
  isPublished: false,
});

export function useAdminContentBlocks() {
  const contentBlocks = ref<AdminContentBlock[]>([]);
  const selectedBlockId = ref('');
  const selectedBlock = ref<AdminContentBlock | null>(null);
  const form = reactive<AdminContentBlockUpdatePayload>(defaultForm());
  const createForm = reactive<AdminContentBlockCreatePayload>(defaultForm());
  const searchQuery = ref('');
  const surfaceFilter = ref('');
  const activeFilter = ref<ToggleFilter>('all');
  const publicationFilter = ref<ToggleFilter>('all');
  const isCreating = ref(false);

  const isListLoading = ref(false);
  const isDetailLoading = ref(false);
  const isSaving = ref(false);
  const isCreateSaving = ref(false);

  const listErrorMessage = ref('');
  const detailErrorMessage = ref('');
  const saveErrorMessage = ref('');
  const saveSuccessMessage = ref('');
  const createErrorMessage = ref('');
  const createSuccessMessage = ref('');

  const filteredBlocks = computed(() => {
    const query = searchQuery.value.trim().toLowerCase();

    return contentBlocks.value.filter((block) => {
      const matchesSearch =
        !query ||
        `${block.title} ${block.key} ${block.body} ${block.surface}`
          .toLowerCase()
          .includes(query);
      const matchesSurface = !surfaceFilter.value || block.surface === surfaceFilter.value;
      const matchesActive =
        activeFilter.value === 'all' ||
        (activeFilter.value === 'yes' && block.isActive) ||
        (activeFilter.value === 'no' && !block.isActive);
      const matchesPublication =
        publicationFilter.value === 'all' ||
        (publicationFilter.value === 'yes' && block.isPublished) ||
        (publicationFilter.value === 'no' && !block.isPublished);

      return matchesSearch && matchesSurface && matchesActive && matchesPublication;
    });
  });

  const surfaceOptions = computed(() => {
    const surfaces = new Set(contentBlocks.value.map((block) => block.surface));
    return Array.from(surfaces).sort();
  });

  async function initialize() {
    await loadContentBlocks();
  }

  async function loadContentBlocks() {
    isListLoading.value = true;
    listErrorMessage.value = '';

    try {
      contentBlocks.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminContentBlocks({ accessToken });
      });

      if (!isCreating.value) {
        const nextSelectedId =
          filteredBlocks.value.find((item) => item.id === selectedBlockId.value)?.id ??
          filteredBlocks.value[0]?.id ??
          '';

        if (nextSelectedId) {
          await selectBlock(nextSelectedId);
        } else {
          selectedBlockId.value = '';
          selectedBlock.value = null;
        }
      }
    } catch (error) {
      listErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить контентные блоки.',
      );
    } finally {
      isListLoading.value = false;
    }
  }

  async function selectBlock(blockId: string) {
    if (!blockId) {
      return;
    }

    isCreating.value = false;
    selectedBlockId.value = blockId;
    detailErrorMessage.value = '';
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';
    isDetailLoading.value = true;

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return getAdminContentBlock({ accessToken, blockId });
      });

      selectedBlock.value = response;
      Object.assign(form, response);
    } catch (error) {
      detailErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось открыть контентный блок.',
      );
    } finally {
      isDetailLoading.value = false;
    }
  }

  function startCreate() {
    isCreating.value = true;
    selectedBlockId.value = '';
    selectedBlock.value = null;
    Object.assign(createForm, defaultForm());
    createErrorMessage.value = '';
    createSuccessMessage.value = '';
  }

  function cancelCreate() {
    isCreating.value = false;
    Object.assign(createForm, defaultForm());
    const fallbackBlockId = filteredBlocks.value[0]?.id;
    if (fallbackBlockId) {
      void selectBlock(fallbackBlockId);
    }
  }

  async function saveCreate() {
    isCreateSaving.value = true;
    createErrorMessage.value = '';
    createSuccessMessage.value = '';

    try {
      const createdBlock = await executeAuthorizedAdminRequest((accessToken) => {
        return createAdminContentBlock({
          accessToken,
          payload: createForm,
        });
      });

      createSuccessMessage.value = 'Контентный блок создан.';
      isCreating.value = false;
      await loadContentBlocks();
      await selectBlock(createdBlock.id);
    } catch (error) {
      createErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось создать контентный блок.',
      );
    } finally {
      isCreateSaving.value = false;
    }
  }

  async function save() {
    if (!selectedBlockId.value) {
      return;
    }

    isSaving.value = true;
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';

    try {
      const savedBlock = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminContentBlock({
          accessToken,
          blockId: selectedBlockId.value,
          payload: form,
        });
      });

      selectedBlock.value = savedBlock;
      contentBlocks.value = contentBlocks.value.map((item) => {
        return item.id === savedBlock.id ? savedBlock : item;
      });
      saveSuccessMessage.value = 'Контентный блок сохранен.';
    } catch (error) {
      saveErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить контентный блок.',
      );
    } finally {
      isSaving.value = false;
    }
  }

  return {
    activeFilter,
    cancelCreate,
    contentBlocks,
    createErrorMessage,
    createForm,
    createSuccessMessage,
    detailErrorMessage,
    filteredBlocks,
    form,
    initialize,
    isCreateSaving,
    isCreating,
    isDetailLoading,
    isListLoading,
    isSaving,
    listErrorMessage,
    loadContentBlocks,
    publicationFilter,
    save,
    saveCreate,
    saveErrorMessage,
    saveSuccessMessage,
    searchQuery,
    selectBlock,
    selectedBlock,
    selectedBlockId,
    startCreate,
    surfaceFilter,
    surfaceOptions,
  };
}
