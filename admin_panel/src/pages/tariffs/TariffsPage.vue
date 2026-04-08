<template>
  <AdminCrudWorkspace
    eyebrow="Коммерческие условия"
    title="Тарифы и правила"
    description="Цены посещения, правила и пояснения для мобильных surfaces по каждому филиалу."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--secondary"
        @click="pricesRulesManager.initialize"
      >
        Обновить филиалы
      </button>
    </template>

    <template #list>
      <div class="admin-section-heading">
        <h2>Филиалы</h2>
        <p>Выберите филиал слева, чтобы настроить тарифы и правила, которые увидят родители в приложении.</p>
      </div>

      <AdminSearchField
        v-model="searchQuery"
        placeholder="Найти филиал"
      />

      <StatePanel
        v-if="pricesRulesManager.isBranchesLoading"
        title="Загружаем филиалы"
        description="Подготавливаем список филиалов для настройки тарифов."
      />

      <StatePanel
        v-else-if="pricesRulesManager.branchesErrorMessage"
        title="Не удалось загрузить филиалы"
        :description="pricesRulesManager.branchesErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            type="button"
            class="admin-button admin-button--secondary"
            @click="pricesRulesManager.initialize"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <StatePanel
        v-else-if="filteredBranches.length === 0"
        title="Филиалы не найдены"
        description="Измените поисковый запрос, чтобы снова увидеть список."
      />

      <div v-else class="admin-list-records">
        <button
          v-for="branch in filteredBranches"
          :key="branch.id"
          type="button"
          class="admin-list-record"
          :class="{
            'admin-list-record--active': branch.id === pricesRulesManager.selectedBranchId,
          }"
          @click="pricesRulesManager.selectBranch(branch.id)"
        >
          <span class="admin-list-record__accent" aria-hidden="true"></span>
          <div class="admin-list-record__copy">
            <strong>{{ branch.name }}</strong>
            <p>{{ branch.city }} · {{ branch.shortLabel }}</p>
            <span>{{ branch.workingHours }}</span>
          </div>
          <StatusBadge
            :label="resolveActiveStatus(branch.isActive).label"
            :tone="resolveActiveStatus(branch.isActive).tone"
          />
        </button>
      </div>
    </template>

    <template #detail>
      <StatePanel
        v-if="pricesRulesManager.isContentLoading"
        title="Открываем тарифы и правила"
        description="Подтягиваем текущий профиль выбранного филиала."
      />

      <StatePanel
        v-else-if="pricesRulesManager.contentErrorMessage"
        title="Не удалось открыть тарифы и правила"
        :description="pricesRulesManager.contentErrorMessage"
        tone="error"
      >
        <template #actions>
          <button
            v-if="pricesRulesManager.selectedBranchId"
            type="button"
            class="admin-button admin-button--secondary"
            @click="pricesRulesManager.selectBranch(pricesRulesManager.selectedBranchId)"
          >
            Повторить
          </button>
        </template>
      </StatePanel>

      <template v-else-if="selectedBranch">
        <header class="admin-detail-header">
          <div class="admin-detail-header__copy">
            <p class="admin-detail-header__eyebrow">Код: {{ selectedBranch.id }}</p>
            <div class="admin-detail-header__title-row">
              <h2>{{ selectedBranch.name }}</h2>
              <StatusBadge
                :label="resolveActiveStatus(selectedBranch.isActive).label"
                :tone="resolveActiveStatus(selectedBranch.isActive).tone"
              />
            </div>
            <p class="admin-detail-header__summary">
              {{ selectedBranch.city }} · {{ selectedBranch.shortLabel }}
            </p>
          </div>
        </header>

        <StatePanel
          v-if="!pricesRulesManager.hasExistingProfile"
          title="Профиль цен еще не создан"
          description="Заполните поля ниже и сохраните. Первый профиль для этого филиала будет создан автоматически."
        />

        <form class="admin-form-stack" @submit.prevent="pricesRulesManager.save">
          <div class="admin-section-heading">
            <h3>Верхний блок</h3>
            <p>Короткое описание, подводка к тарифам и заметка про дни рождения.</p>
          </div>

          <div class="admin-form-grid--two">
            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Заголовок</span>
              <input
                v-model="pricesRulesManager.form.introTitle"
                class="admin-control"
              />
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Описание</span>
              <textarea
                v-model="pricesRulesManager.form.introDescription"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Блок про день рождения</span>
              <textarea
                v-model="pricesRulesManager.form.birthdayNote"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>

            <label class="admin-field admin-field--full">
              <span class="admin-field__label">Дисклеймер</span>
              <textarea
                v-model="pricesRulesManager.form.disclaimer"
                class="admin-control admin-control--textarea"
              ></textarea>
            </label>
          </div>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Тарифы посещения</h3>
              <p>Каждая карточка — отдельный тариф для экрана цен в мобильном приложении.</p>
            </div>

            <div class="admin-repeater">
              <article
                v-for="(tariff, index) in pricesRulesManager.form.visitTariffs"
                :key="`tariff-${index}`"
                class="admin-repeater__item"
              >
                <div class="admin-repeater__header">
                  <strong>Тариф {{ index + 1 }}</strong>
                  <button
                    type="button"
                    class="admin-button admin-button--ghost"
                    @click="pricesRulesManager.removeTariff(index)"
                  >
                    Удалить
                  </button>
                </div>

                <div class="admin-repeater__grid">
                  <label class="admin-field">
                    <span class="admin-field__label">Название</span>
                    <input v-model="tariff.title" class="admin-control" />
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Подпись цены</span>
                    <input v-model="tariff.priceLabel" class="admin-control" />
                  </label>

                  <label class="admin-field admin-field--full">
                    <span class="admin-field__label">Описание</span>
                    <textarea
                      v-model="tariff.description"
                      class="admin-control admin-control--textarea"
                    ></textarea>
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Порядок</span>
                    <input
                      v-model.number="tariff.displayOrder"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>
                </div>

                <AdminSwitchField
                  v-model="tariff.isActive"
                  label="Тариф активен"
                  hint="Неактивный тариф не будет показан в приложении."
                />
              </article>
            </div>

            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="pricesRulesManager.addTariff"
            >
              Добавить тариф
            </button>
          </section>

          <section class="admin-panel admin-panel--stack admin-panel--muted">
            <div class="admin-section-heading">
              <h3>Правила посещения</h3>
              <p>Добавляйте и выключайте отдельные правила без правок в коде мобильного приложения.</p>
            </div>

            <div class="admin-repeater">
              <article
                v-for="(rule, index) in pricesRulesManager.form.rules"
                :key="`rule-${index}`"
                class="admin-repeater__item"
              >
                <div class="admin-repeater__header">
                  <strong>Правило {{ index + 1 }}</strong>
                  <button
                    type="button"
                    class="admin-button admin-button--ghost"
                    @click="pricesRulesManager.removeRule(index)"
                  >
                    Удалить
                  </button>
                </div>

                <div class="admin-repeater__grid">
                  <label class="admin-field admin-field--full">
                    <span class="admin-field__label">Текст правила</span>
                    <textarea
                      v-model="rule.text"
                      class="admin-control admin-control--textarea"
                    ></textarea>
                  </label>

                  <label class="admin-field">
                    <span class="admin-field__label">Порядок</span>
                    <input
                      v-model.number="rule.displayOrder"
                      min="0"
                      type="number"
                      class="admin-control"
                    />
                  </label>
                </div>

                <AdminSwitchField
                  v-model="rule.isActive"
                  label="Правило активно"
                  hint="Неактивное правило не показывается в мобильном приложении."
                />
              </article>
            </div>

            <button
              type="button"
              class="admin-button admin-button--secondary"
              @click="pricesRulesManager.addRule"
            >
              Добавить правило
            </button>
          </section>

          <p
            v-if="pricesRulesManager.successMessage"
            class="admin-inline-message admin-inline-message--success"
          >
            {{ pricesRulesManager.successMessage }}
          </p>

          <div class="admin-form-actions">
            <button
              type="submit"
              class="admin-button admin-button--primary"
              :disabled="pricesRulesManager.isSaving"
            >
              {{ pricesRulesManager.isSaving ? 'Сохраняем…' : 'Сохранить тарифы и правила' }}
            </button>
          </div>
        </form>
      </template>

      <StatePanel
        v-else
        title="Выберите филиал слева"
        description="Тарифы и правила откроются справа после выбора филиала."
      />
    </template>
  </AdminCrudWorkspace>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';

import { useBranchPricesRulesManager } from '@/features/branches/model/useBranchPricesRulesManager';
import { resolveActiveStatus } from '@/shared/lib/adminStatus';
import AdminCrudWorkspace from '@/shared/ui/AdminCrudWorkspace.vue';
import AdminSearchField from '@/shared/ui/AdminSearchField.vue';
import AdminSwitchField from '@/shared/ui/AdminSwitchField.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

const pricesRulesManager = reactive(useBranchPricesRulesManager());
const searchQuery = ref('');

const filteredBranches = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) {
    return pricesRulesManager.branchOptions;
  }

  return pricesRulesManager.branchOptions.filter((branch) => {
    return `${branch.name} ${branch.city} ${branch.shortLabel}`
      .toLowerCase()
      .includes(query);
  });
});

const selectedBranch = computed(() => {
  return pricesRulesManager.branchOptions.find((branch) => {
    return branch.id === pricesRulesManager.selectedBranchId;
  }) ?? null;
});

onMounted(() => {
  void pricesRulesManager.initialize();
});
</script>
