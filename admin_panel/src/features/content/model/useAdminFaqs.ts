import { computed, reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import {
  createAdminFaq,
  getAdminFaq,
  listAdminFaqs,
  updateAdminFaq,
} from '@/features/content/api/adminContentApi';
import type {
  AdminFaq,
  AdminFaqCreatePayload,
  AdminFaqUpdatePayload,
} from '@/features/content/model/adminContent';

type ToggleFilter = 'all' | 'yes' | 'no';

const defaultForm = (): AdminFaqCreatePayload => ({
  question: '',
  answer: '',
  displayOrder: 0,
  isActive: true,
  isPublished: false,
});

export function useAdminFaqs() {
  const faqs = ref<AdminFaq[]>([]);
  const selectedFaqId = ref('');
  const selectedFaq = ref<AdminFaq | null>(null);
  const form = reactive<AdminFaqUpdatePayload>(defaultForm());
  const createForm = reactive<AdminFaqCreatePayload>(defaultForm());
  const searchQuery = ref('');
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

  const filteredFaqs = computed(() => {
    const query = searchQuery.value.trim().toLowerCase();

    return faqs.value.filter((faq) => {
      const matchesSearch =
        !query ||
        `${faq.question} ${faq.answer}`.toLowerCase().includes(query);
      const matchesActive =
        activeFilter.value === 'all' ||
        (activeFilter.value === 'yes' && faq.isActive) ||
        (activeFilter.value === 'no' && !faq.isActive);
      const matchesPublication =
        publicationFilter.value === 'all' ||
        (publicationFilter.value === 'yes' && faq.isPublished) ||
        (publicationFilter.value === 'no' && !faq.isPublished);

      return matchesSearch && matchesActive && matchesPublication;
    });
  });

  async function initialize() {
    await loadFaqs();
  }

  async function loadFaqs() {
    isListLoading.value = true;
    listErrorMessage.value = '';

    try {
      faqs.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminFaqs({ accessToken });
      });

      if (!isCreating.value) {
        const nextSelectedId =
          filteredFaqs.value.find((item) => item.id === selectedFaqId.value)?.id ??
          filteredFaqs.value[0]?.id ??
          '';

        if (nextSelectedId) {
          await selectFaq(nextSelectedId);
        } else {
          selectedFaqId.value = '';
          selectedFaq.value = null;
        }
      }
    } catch (error) {
      listErrorMessage.value = resolveAdminRequestError(error, 'Не удалось загрузить FAQ.');
    } finally {
      isListLoading.value = false;
    }
  }

  async function selectFaq(faqId: string) {
    if (!faqId) {
      return;
    }

    isCreating.value = false;
    selectedFaqId.value = faqId;
    detailErrorMessage.value = '';
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';
    isDetailLoading.value = true;

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return getAdminFaq({ accessToken, faqId });
      });

      selectedFaq.value = response;
      Object.assign(form, response);
    } catch (error) {
      detailErrorMessage.value = resolveAdminRequestError(error, 'Не удалось открыть FAQ.');
    } finally {
      isDetailLoading.value = false;
    }
  }

  function startCreate() {
    isCreating.value = true;
    selectedFaqId.value = '';
    selectedFaq.value = null;
    Object.assign(createForm, defaultForm());
    createErrorMessage.value = '';
    createSuccessMessage.value = '';
  }

  function cancelCreate() {
    isCreating.value = false;
    Object.assign(createForm, defaultForm());
    const fallbackFaqId = filteredFaqs.value[0]?.id;
    if (fallbackFaqId) {
      void selectFaq(fallbackFaqId);
    }
  }

  async function saveCreate() {
    isCreateSaving.value = true;
    createErrorMessage.value = '';
    createSuccessMessage.value = '';

    try {
      const createdFaq = await executeAuthorizedAdminRequest((accessToken) => {
        return createAdminFaq({
          accessToken,
          payload: createForm,
        });
      });

      createSuccessMessage.value = 'FAQ создан.';
      isCreating.value = false;
      await loadFaqs();
      await selectFaq(createdFaq.id);
    } catch (error) {
      createErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось создать FAQ.',
      );
      throw error;
    } finally {
      isCreateSaving.value = false;
    }
  }

  async function save() {
    if (!selectedFaqId.value) {
      return;
    }

    isSaving.value = true;
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';

    try {
      const savedFaq = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminFaq({
          accessToken,
          faqId: selectedFaqId.value,
          payload: form,
        });
      });

      selectedFaq.value = savedFaq;
      faqs.value = faqs.value.map((item) => (item.id === savedFaq.id ? savedFaq : item));
      saveSuccessMessage.value = 'FAQ сохранен.';
    } catch (error) {
      saveErrorMessage.value = resolveAdminRequestError(error, 'Не удалось сохранить FAQ.');
      throw error;
    } finally {
      isSaving.value = false;
    }
  }

  return {
    activeFilter,
    cancelCreate,
    createErrorMessage,
    createForm,
    createSuccessMessage,
    detailErrorMessage,
    faqs,
    filteredFaqs,
    form,
    initialize,
    isCreateSaving,
    isCreating,
    isDetailLoading,
    isListLoading,
    isSaving,
    listErrorMessage,
    loadFaqs,
    publicationFilter,
    save,
    saveCreate,
    saveErrorMessage,
    saveSuccessMessage,
    searchQuery,
    selectFaq,
    selectedFaq,
    selectedFaqId,
    startCreate,
  };
}
