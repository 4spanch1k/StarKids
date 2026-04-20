import { computed, reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import {
  createAdminNews,
  deleteAdminNews,
  getAdminNews,
  listAdminNews,
  updateAdminNews,
  uploadAdminNewsImage,
} from '@/features/news/api/adminNewsApi';
import type {
  AdminNews,
  AdminNewsCreatePayload,
  AdminNewsUpdatePayload,
} from '@/features/news/model/adminNews';

type ActiveFilter = 'all' | 'active' | 'inactive';

const defaultForm = (): AdminNewsCreatePayload => ({
  title: '',
  imageUrl: '',
  description: '',
  isActive: true,
});

export function useAdminNews() {
  const news = ref<AdminNews[]>([]);
  const selectedNewsId = ref('');
  const selectedNews = ref<AdminNews | null>(null);
  const form = reactive<AdminNewsUpdatePayload>(defaultForm());
  const createForm = reactive<AdminNewsCreatePayload>(defaultForm());
  const searchQuery = ref('');
  const activeFilter = ref<ActiveFilter>('all');
  const isCreating = ref(false);

  const isListLoading = ref(false);
  const isDetailLoading = ref(false);
  const isSaving = ref(false);
  const isCreateSaving = ref(false);
  const isCreateImageUploading = ref(false);
  const isEditImageUploading = ref(false);

  const listErrorMessage = ref('');
  const detailErrorMessage = ref('');
  const saveErrorMessage = ref('');
  const saveSuccessMessage = ref('');
  const createErrorMessage = ref('');
  const createSuccessMessage = ref('');

  const filteredNews = computed(() => {
    const query = searchQuery.value.trim().toLowerCase();

    return news.value.filter((item) => {
      const matchesSearch =
        !query ||
        `${item.title} ${item.description}`.toLowerCase().includes(query);
      const matchesActive =
        activeFilter.value === 'all' ||
        (activeFilter.value === 'active' && item.isActive) ||
        (activeFilter.value === 'inactive' && !item.isActive);

      return matchesSearch && matchesActive;
    });
  });

  async function initialize() {
    await loadNews();
  }

  async function loadNews() {
    isListLoading.value = true;
    listErrorMessage.value = '';

    try {
      news.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminNews({ accessToken });
      });

      if (
        selectedNewsId.value &&
        !news.value.some((item) => item.id === selectedNewsId.value)
      ) {
        selectedNewsId.value = '';
        selectedNews.value = null;
      }
    } catch (error) {
      listErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить новости.',
      );
    } finally {
      isListLoading.value = false;
    }
  }

  async function selectNews(newsId: string) {
    if (!newsId) {
      return;
    }

    isCreating.value = false;
    selectedNewsId.value = newsId;
    detailErrorMessage.value = '';
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';
    isDetailLoading.value = true;

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return getAdminNews({ accessToken, newsId });
      });

      selectedNews.value = response;
      Object.assign(form, {
        title: response.title,
        imageUrl: response.imageUrl,
        description: response.description,
        isActive: response.isActive,
      });
    } catch (error) {
      detailErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось открыть новость.',
      );
    } finally {
      isDetailLoading.value = false;
    }
  }

  function startCreate() {
    isCreating.value = true;
    selectedNewsId.value = '';
    selectedNews.value = null;
    Object.assign(createForm, defaultForm());
    createErrorMessage.value = '';
    createSuccessMessage.value = '';
  }

  function cancelCreate() {
    isCreating.value = false;
    Object.assign(createForm, defaultForm());
  }

  async function saveCreate() {
    isCreateSaving.value = true;
    createErrorMessage.value = '';
    createSuccessMessage.value = '';

    try {
      const createdNews = await executeAuthorizedAdminRequest((accessToken) => {
        return createAdminNews({
          accessToken,
          payload: createForm,
        });
      });

      createSuccessMessage.value = 'Новость создана.';
      isCreating.value = false;
      selectedNewsId.value = createdNews.id;
      selectedNews.value = createdNews;
      await loadNews();
      await selectNews(createdNews.id);
      return createdNews;
    } catch (error) {
      createErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось создать новость.',
      );
      throw error;
    } finally {
      isCreateSaving.value = false;
    }
  }

  async function save() {
    if (!selectedNewsId.value) {
      return null;
    }

    isSaving.value = true;
    saveErrorMessage.value = '';
    saveSuccessMessage.value = '';

    try {
      const savedNews = await executeAuthorizedAdminRequest((accessToken) => {
        return updateAdminNews({
          accessToken,
          newsId: selectedNewsId.value,
          payload: form,
        });
      });

      selectedNews.value = savedNews;
      news.value = news.value.map((item) => {
        return item.id === savedNews.id ? savedNews : item;
      });
      saveSuccessMessage.value = 'Новость сохранена.';
      return savedNews;
    } catch (error) {
      saveErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить новость.',
      );
      throw error;
    } finally {
      isSaving.value = false;
    }
  }

  async function removeSelectedNews() {
    if (!selectedNewsId.value) {
      return;
    }

    const newsId = selectedNewsId.value;
    await executeAuthorizedAdminRequest((accessToken) => {
      return deleteAdminNews({ accessToken, newsId });
    });

    selectedNewsId.value = '';
    selectedNews.value = null;
    Object.assign(form, defaultForm());
    await loadNews();
  }

  async function uploadCreateImage(file: File) {
    isCreateImageUploading.value = true;
    createErrorMessage.value = '';

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return uploadAdminNewsImage({ accessToken, file });
      });

      createForm.imageUrl = response.imageUrl;
      return response.imageUrl;
    } catch (error) {
      createErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить изображение новости.',
      );
      throw error;
    } finally {
      isCreateImageUploading.value = false;
    }
  }

  async function uploadEditImage(file: File) {
    isEditImageUploading.value = true;
    saveErrorMessage.value = '';

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return uploadAdminNewsImage({ accessToken, file });
      });

      form.imageUrl = response.imageUrl;
      return response.imageUrl;
    } catch (error) {
      saveErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить изображение новости.',
      );
      throw error;
    } finally {
      isEditImageUploading.value = false;
    }
  }

  return {
    activeFilter,
    cancelCreate,
    createErrorMessage,
    createForm,
    createSuccessMessage,
    detailErrorMessage,
    filteredNews,
    form,
    initialize,
    isCreateImageUploading,
    isCreateSaving,
    isCreating,
    isDetailLoading,
    isEditImageUploading,
    isListLoading,
    isSaving,
    listErrorMessage,
    loadNews,
    news,
    removeSelectedNews,
    save,
    saveCreate,
    saveErrorMessage,
    saveSuccessMessage,
    searchQuery,
    selectNews,
    selectedNews,
    selectedNewsId,
    startCreate,
    uploadCreateImage,
    uploadEditImage,
  };
}
