import { reactive, ref } from 'vue';

import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import {
  getAdminBranchPricesRules,
  listAdminBranches,
  upsertAdminBranchPricesRules,
} from '@/features/branches/api/adminBranchesApi';
import type {
  AdminBranchPricesRules,
  AdminBranchPricesRulesPayload,
  AdminBranchRule,
  AdminBranchSummary,
  AdminBranchTariff,
} from '@/features/branches/model/adminBranch';
import { HttpError } from '@/shared/api/httpClient';

const defaultTariff = (): AdminBranchTariff => ({
  title: '',
  priceLabel: '',
  description: '',
  displayOrder: 0,
  isActive: true,
});

const defaultRule = (): AdminBranchRule => ({
  text: '',
  displayOrder: 0,
  isActive: true,
});

const defaultForm = (): AdminBranchPricesRulesPayload => ({
  introTitle: '',
  introDescription: '',
  birthdayNote: '',
  disclaimer: '',
  visitTariffs: [defaultTariff()],
  rules: [defaultRule()],
});

export function useBranchPricesRulesManager() {
  const branchOptions = ref<AdminBranchSummary[]>([]);
  const selectedBranchId = ref('');
  const isBranchesLoading = ref(false);
  const isContentLoading = ref(false);
  const isSaving = ref(false);
  const branchesErrorMessage = ref('');
  const contentErrorMessage = ref('');
  const successMessage = ref('');
  const hasExistingProfile = ref(false);

  const form = reactive<AdminBranchPricesRulesPayload>(defaultForm());

  async function initialize() {
    await loadBranchOptions();
  }

  async function loadBranchOptions() {
    isBranchesLoading.value = true;
    branchesErrorMessage.value = '';

    try {
      branchOptions.value = await executeAuthorizedAdminRequest((accessToken) => {
        return listAdminBranches({ accessToken, includeInactive: true });
      });

      const fallbackBranchId = selectedBranchId.value || branchOptions.value[0]?.id || '';
      if (fallbackBranchId) {
        await selectBranch(fallbackBranchId);
      }
    } catch (error) {
      branchesErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось загрузить филиалы для раздела тарифов.',
      );
    } finally {
      isBranchesLoading.value = false;
    }
  }

  async function selectBranch(branchId: string) {
    if (!branchId) {
      return;
    }

    selectedBranchId.value = branchId;
    successMessage.value = '';
    contentErrorMessage.value = '';
    isContentLoading.value = true;

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return getAdminBranchPricesRules({ accessToken, branchId });
      });

      applyForm(response);
      hasExistingProfile.value = true;
    } catch (error) {
      if (error instanceof HttpError && error.status === 404) {
        Object.assign(form, defaultForm());
        hasExistingProfile.value = false;
      } else {
        contentErrorMessage.value = resolveAdminRequestError(
          error,
          'Не удалось открыть тарифы и правила филиала.',
        );
      }
    } finally {
      isContentLoading.value = false;
    }
  }

  async function save() {
    if (!selectedBranchId.value) {
      return;
    }

    isSaving.value = true;
    contentErrorMessage.value = '';
    successMessage.value = '';

    try {
      const response = await executeAuthorizedAdminRequest((accessToken) => {
        return upsertAdminBranchPricesRules({
          accessToken,
          branchId: selectedBranchId.value,
          payload: form,
        });
      });

      applyForm(response);
      hasExistingProfile.value = true;
      successMessage.value = 'Тарифы и правила сохранены.';
    } catch (error) {
      contentErrorMessage.value = resolveAdminRequestError(
        error,
        'Не удалось сохранить тарифы и правила.',
      );
    } finally {
      isSaving.value = false;
    }
  }

  function addTariff() {
    form.visitTariffs.push(defaultTariff());
  }

  function removeTariff(index: number) {
    form.visitTariffs.splice(index, 1);
    if (form.visitTariffs.length === 0) {
      form.visitTariffs.push(defaultTariff());
    }
  }

  function addRule() {
    form.rules.push(defaultRule());
  }

  function removeRule(index: number) {
    form.rules.splice(index, 1);
    if (form.rules.length === 0) {
      form.rules.push(defaultRule());
    }
  }

  function applyForm(response: AdminBranchPricesRules) {
    Object.assign(form, {
      introTitle: response.introTitle,
      introDescription: response.introDescription,
      birthdayNote: response.birthdayNote,
      disclaimer: response.disclaimer,
      visitTariffs: response.visitTariffs.map((tariff) => ({
        title: tariff.title,
        priceLabel: tariff.priceLabel,
        description: tariff.description,
        displayOrder: tariff.displayOrder,
        isActive: tariff.isActive,
      })),
      rules: response.rules.map((rule) => ({
        text: rule.text,
        displayOrder: rule.displayOrder,
        isActive: rule.isActive,
      })),
    });

    if (form.visitTariffs.length === 0) {
      form.visitTariffs.push(defaultTariff());
    }
    if (form.rules.length === 0) {
      form.rules.push(defaultRule());
    }
  }

  return {
    addRule,
    addTariff,
    branchOptions,
    branchesErrorMessage,
    contentErrorMessage,
    form,
    hasExistingProfile,
    initialize,
    isBranchesLoading,
    isContentLoading,
    isSaving,
    removeRule,
    removeTariff,
    save,
    selectBranch,
    selectedBranchId,
    successMessage,
  };
}
