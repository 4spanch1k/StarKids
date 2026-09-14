<template>
  <PageShell
    eyebrow="Доступ к филиалам"
    title="Сотрудники"
    description="Назначайте операторам ровно один активный филиал для входа и поиска билетов."
  >
    <template #actions>
      <button
        type="button"
        class="admin-button admin-button--secondary"
        :disabled="isLoading"
        @click="void loadStaff()"
      >
        {{ isLoading ? 'Обновляем…' : 'Обновить' }}
      </button>
    </template>

    <section class="admin-panel admin-panel--stack">
      <StatePanel
        v-if="isLoading && staff.length === 0"
        title="Загружаем сотрудников"
        description="Получаем текущие роли и назначения филиалов."
      />
      <StatePanel
        v-else-if="errorMessage"
        title="Не удалось загрузить сотрудников"
        :description="errorMessage"
        tone="error"
      >
        <template #actions>
          <button type="button" class="admin-button admin-button--secondary" @click="void loadStaff()">
            Повторить
          </button>
        </template>
      </StatePanel>
      <StatePanel
        v-else-if="staff.length === 0"
        title="Сотрудники не найдены"
        description="В системе пока нет администраторов."
      />
      <div v-else class="staff-table-wrap">
        <table class="staff-table">
          <thead>
            <tr>
              <th>Сотрудник</th>
              <th>Роль</th>
              <th>Статус</th>
              <th>Филиал для admission</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="member in staff" :key="member.id">
              <td>
                <strong>{{ member.full_name || 'Без имени' }}</strong>
                <span>{{ member.email }}</span>
              </td>
              <td>{{ roleLabel(member.role) }}</td>
              <td>{{ member.is_active ? 'Активен' : 'Отключён' }}</td>
              <td>
                <select
                  v-if="member.role === 'operator'"
                  class="admin-control staff-branch-select"
                  :value="member.branch_id ?? ''"
                  :disabled="Boolean(savingIds[member.id])"
                  @change="void changeBranch(member, ($event.target as HTMLSelectElement).value || null)"
                >
                  <option value="">Выберите филиал</option>
                  <option v-for="branch in activeBranches" :key="branch.id" :value="branch.id">
                    {{ branch.name }} · {{ branch.city }}
                  </option>
                </select>
                <span v-else class="staff-global-scope">
                  {{ member.role === 'super_admin' ? 'Глобальный доступ' : 'Не применяется' }}
                </span>
                <small v-if="savingIds[member.id]" class="admin-copy-muted">Сохраняем…</small>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-if="successMessage" class="staff-success" role="status">{{ successMessage }}</p>
      <p v-if="saveErrorMessage" class="staff-error" role="alert">{{ saveErrorMessage }}</p>
    </section>
  </PageShell>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';

import { listAdminBranches } from '@/features/branches/api/adminBranchesApi';
import { fetchAdminStaff, updateAdminStaffBranch, type AdminStaffMember } from '@/features/staff/api/adminStaffApi';
import { executeAuthorizedAdminRequest, resolveAdminRequestError } from '@/features/auth/lib/adminRequest';
import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';

type ActiveBranch = { id: string; name: string; city: string };

const staff = ref<AdminStaffMember[]>([]);
const branches = ref<ActiveBranch[]>([]);
const isLoading = ref(false);
const errorMessage = ref('');
const saveErrorMessage = ref('');
const successMessage = ref('');
const savingIds = reactive<Record<string, boolean>>({});

const activeBranches = computed(() => branches.value);

onMounted(() => {
  void loadStaff();
});

async function loadStaff() {
  isLoading.value = true;
  errorMessage.value = '';
  try {
    const [staffResponse, branchResponse] = await Promise.all([
      fetchAdminStaff(),
      executeAuthorizedAdminRequest((accessToken) => listAdminBranches({ accessToken, includeInactive: true })),
    ]);
    staff.value = staffResponse;
    branches.value = branchResponse
      .filter((branch) => branch.isActive)
      .map((branch) => ({ id: branch.id, name: branch.name, city: branch.city }));
  } catch (error) {
    errorMessage.value = resolveAdminRequestError(error, 'Не удалось загрузить сотрудников.');
  } finally {
    isLoading.value = false;
  }
}

async function changeBranch(member: AdminStaffMember, branchId: string | null) {
  if (member.role !== 'operator' || savingIds[member.id]) return;
  saveErrorMessage.value = '';
  successMessage.value = '';
  savingIds[member.id] = true;
  try {
    const updated = await updateAdminStaffBranch(member.id, branchId);
    const index = staff.value.findIndex((item) => item.id === member.id);
    if (index >= 0) staff.value[index] = updated;
    successMessage.value = `Филиал оператора ${updated.full_name} обновлён.`;
  } catch (error) {
    saveErrorMessage.value = resolveAdminRequestError(error, 'Не удалось сохранить филиал оператора.');
  } finally {
    savingIds[member.id] = false;
  }
}

function roleLabel(role: string): string {
  return ({
    super_admin: 'Суперадмин',
    operator: 'Оператор',
    content_manager: 'Контент-менеджер',
    sales_manager: 'Менеджер продаж',
  } as Record<string, string>)[role] ?? role;
}
</script>

<style scoped>
.staff-table-wrap { overflow-x: auto; }
.staff-table { width: 100%; min-width: 720px; border-collapse: collapse; font-size: 13px; }
.staff-table th, .staff-table td { padding: 12px 10px; border-bottom: 1px solid var(--color-border); text-align: left; vertical-align: middle; }
.staff-table th { color: var(--color-muted); font-size: 11px; letter-spacing: .04em; text-transform: uppercase; }
.staff-table td:first-child { display: grid; gap: 3px; }
.staff-table td:first-child span { color: var(--color-muted); font-size: 12px; }
.staff-branch-select { min-width: 240px; }
.staff-global-scope { color: var(--color-muted); }
.staff-success { color: var(--color-success); font-size: 13px; }
.staff-error { color: var(--color-danger); font-size: 13px; }
</style>
