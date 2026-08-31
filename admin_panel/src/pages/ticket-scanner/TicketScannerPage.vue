<template>
  <PageShell
    eyebrow="Операционный вход"
    title="Сканер билетов"
    description="Проверяйте подписанный QR-код перед входом. Без связи билет не считается подтверждённым."
  >
    <section class="scanner-grid">
      <div class="scanner-panel scanner-panel--controls">
        <div class="scanner-section-heading">
          <div>
            <p class="scanner-eyebrow">Филиал</p>
            <h2>Где проходит вход?</h2>
          </div>
          <span v-if="selectedBranch" class="scanner-branch-state">Выбран</span>
        </div>

        <select
          v-model="selectedBranchId"
          class="admin-control"
          :disabled="isRedeeming || isScannerActive"
          aria-label="Выберите филиал"
        >
          <option value="">Выберите филиал</option>
          <option v-for="branch in branches" :key="branch.id" :value="branch.id">
            {{ branch.name }} · {{ branch.city }}
          </option>
        </select>

        <div v-if="branchesLoading" class="scanner-hint">Загружаем филиалы…</div>
        <div v-else-if="branchesError" class="scanner-inline-error">
          {{ branchesError }}
          <button type="button" class="admin-button admin-button--ghost" @click="loadBranches">
            Повторить
          </button>
        </div>
      </div>

      <div class="scanner-panel scanner-panel--camera">
        <div class="scanner-section-heading">
          <div>
            <p class="scanner-eyebrow">Камера</p>
            <h2>Наведите камеру на QR</h2>
          </div>
          <span class="scanner-lock" :class="{ 'scanner-lock--active': isRedeeming }">
            {{ isRedeeming ? 'Проверяем…' : 'Готов к сканированию' }}
          </span>
        </div>

        <div id="ticket-qr-reader" ref="readerElement" class="scanner-reader" :class="{ 'scanner-reader--active': isScannerActive }">
          <div v-if="!isScannerActive" class="scanner-reader__placeholder">
            <span class="scanner-reader__icon" aria-hidden="true">⌁</span>
            <strong>{{ selectedBranchId ? 'Камера выключена' : 'Сначала выберите филиал' }}</strong>
            <span>{{ selectedBranchId ? 'Нажмите «Включить камеру», чтобы начать.' : 'Выбор филиала обязателен для входа.' }}</span>
          </div>
        </div>

        <div class="scanner-actions">
          <button
            v-if="!isScannerActive"
            type="button"
            class="admin-button admin-button--primary"
            :disabled="!selectedBranchId || branchesLoading || isRedeeming"
            @click="startScanner"
          >
            Включить камеру
          </button>
          <button
            v-else
            type="button"
            class="admin-button admin-button--secondary"
            :disabled="isRedeeming"
            @click="stopScanner"
          >
            Остановить камеру
          </button>
        </div>

        <p v-if="cameraError" class="scanner-inline-error">{{ cameraError }}</p>
      </div>

      <section v-if="result" class="scanner-result" :class="resultToneClass" aria-live="assertive">
        <div class="scanner-result__icon" aria-hidden="true">{{ resultIcon }}</div>
        <div class="scanner-result__copy">
          <p class="scanner-eyebrow">{{ result.outcome }}</p>
          <h2>{{ resultTitle }}</h2>
          <template v-if="result.ticket">
            <strong>{{ result.ticket.title }}</strong>
            <span>{{ result.ticket.ticketNumber }} · {{ result.ticket.branchName }}</span>
            <span v-if="result.ticket.redeemedAt">Время входа: {{ formatDateTime(result.ticket.redeemedAt) }}</span>
          </template>
          <span v-if="result.errorMessage">{{ result.errorMessage }}</span>
        </div>
        <button type="button" class="admin-button admin-button--primary" :disabled="isRedeeming" @click="scanNext">
          Сканировать следующий
        </button>
      </section>
    </section>
  </PageShell>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { Html5Qrcode } from 'html5-qrcode';

import { useSessionStore } from '@/features/auth/stores/useSessionStore';
import { listAdminBranches } from '@/features/branches/api/adminBranchesApi';
import type { AdminBranchSummary } from '@/features/branches/model/adminBranch';
import {
  redeemTicket,
  resolveRedemptionOutcome,
  type RedemptionOutcome,
  type TicketRedemptionResponse,
} from '@/features/ticket-scanner/api/ticketRedemptionApi';
import PageShell from '@/shared/ui/PageShell.vue';
import { resolveAdminRequestError } from '@/features/auth/lib/adminRequest';

const sessionStore = useSessionStore();
const branches = ref<AdminBranchSummary[]>([]);
const selectedBranchId = ref(sessionStorage.getItem('boom-bala.scanner.branch-id') ?? '');
const readerElement = ref<HTMLElement | null>(null);
const branchesLoading = ref(false);
const branchesError = ref('');
const cameraError = ref('');
const isScannerActive = ref(false);
const isRedeeming = ref(false);
const result = ref<{
  outcome: RedemptionOutcome | 'network_error';
  ticket: TicketRedemptionResponse | null;
  errorMessage: string;
} | null>(null);
let scanner: Html5Qrcode | null = null;
let scanLocked = false;

const selectedBranch = computed(() => branches.value.find((branch) => branch.id === selectedBranchId.value));
const resultToneClass = computed(() => {
  if (result.value?.outcome === 'redeemed') return 'scanner-result--success';
  return 'scanner-result--failure';
});
const resultTitle = computed(() => {
  switch (result.value?.outcome) {
    case 'redeemed':
      return 'ВХОД РАЗРЕШЁН';
    case 'already_used':
      return 'Билет уже использован';
    case 'invalid_qr':
      return 'Неверный QR';
    case 'ticket_not_found':
      return 'Билет не найден';
    case 'wrong_branch':
      return 'Билет другого филиала';
    case 'wrong_date':
      return 'Билет на другую дату';
    case 'invalid_status':
      return 'Билет недействителен';
    case 'invalid_ticket_data':
      return 'Ошибка данных билета';
    default:
      return 'Нет связи. Вход не подтверждён.';
  }
});
const resultIcon = computed(() => (result.value?.outcome === 'redeemed' ? '✓' : '!'));

onMounted(() => {
  void loadBranches();
});

watch(selectedBranchId, (branchId) => {
  if (branchId) {
    sessionStorage.setItem('boom-bala.scanner.branch-id', branchId);
  } else {
    sessionStorage.removeItem('boom-bala.scanner.branch-id');
  }
  result.value = null;
  cameraError.value = '';
});

onBeforeUnmount(() => {
  void stopScanner();
});

async function loadBranches() {
  branchesLoading.value = true;
  branchesError.value = '';
  try {
    branches.value = await listAdminBranches({
      accessToken: sessionStore.accessToken,
      includeInactive: false,
    });
    if (!branches.value.some((branch) => branch.id === selectedBranchId.value)) {
      selectedBranchId.value = '';
      sessionStorage.removeItem('boom-bala.scanner.branch-id');
    }
  } catch (error) {
    branchesError.value = resolveAdminRequestError(error, 'Не удалось загрузить филиалы.');
  } finally {
    branchesLoading.value = false;
  }
}

async function startScanner() {
  if (!selectedBranchId.value || isRedeeming.value || isScannerActive.value) return;
  cameraError.value = '';
  result.value = null;
  scanLocked = false;
  sessionStorage.setItem('boom-bala.scanner.branch-id', selectedBranchId.value);
  scanner = new Html5Qrcode('ticket-qr-reader');
  try {
    await scanner.start(
      { facingMode: 'environment' },
      { fps: 10, qrbox: { width: 260, height: 260 }, aspectRatio: 1 },
      handleDetected,
      () => undefined,
    );
    isScannerActive.value = true;
  } catch {
    cameraError.value = 'Не удалось получить доступ к камере. Разрешите камеру и попробуйте снова.';
    try {
      await scanner.clear();
    } catch {
      // A partially initialized camera is safe to discard.
    }
    scanner = null;
  }
}

async function stopScanner() {
  if (!scanner) {
    isScannerActive.value = false;
    return;
  }
  try {
    if (isScannerActive.value) await scanner.stop();
    scanner.clear();
  } catch {
    // Camera cleanup is best effort; redemption remains fail closed.
  } finally {
    scanner = null;
    isScannerActive.value = false;
  }
}

async function handleDetected(decodedText: string) {
  if (scanLocked || isRedeeming.value || !selectedBranchId.value) return;
  scanLocked = true;
  isRedeeming.value = true;
  await stopScanner();
  try {
    const response = await redeemTicket({ qrPayload: decodedText, branchId: selectedBranchId.value });
    result.value = { outcome: response.outcome, ticket: response, errorMessage: '' };
  } catch (error) {
    result.value = {
      outcome: resolveRedemptionOutcome(error),
      ticket: null,
      errorMessage: resolveScannerError(error),
    };
  } finally {
    isRedeeming.value = false;
  }
}

async function scanNext() {
  result.value = null;
  scanLocked = false;
  await startScanner();
}

function resolveScannerError(error: unknown) {
  if (resolveRedemptionOutcome(error) === 'network_error') {
    return 'Нет связи. Вход не подтверждён.';
  }
  return '';
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('ru-RU', {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));
}
</script>

<style scoped>
.scanner-grid {
  display: grid;
  grid-template-columns: minmax(260px, 0.8fr) minmax(420px, 1.2fr);
  gap: 14px;
}

.scanner-panel,
.scanner-result {
  padding: 22px;
  border: 1px solid var(--color-border);
  border-radius: 20px;
  background: var(--color-surface);
  box-shadow: var(--shadow-soft);
}

.scanner-panel--camera {
  grid-row: span 2;
}

.scanner-section-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 16px;
}

.scanner-section-heading h2,
.scanner-result h2 {
  margin: 2px 0 0;
  font-size: 20px;
  line-height: 1.2;
}

.scanner-eyebrow {
  margin: 0;
  color: var(--color-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.scanner-branch-state,
.scanner-lock {
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 700;
}

.scanner-lock--active {
  color: var(--color-accent);
}

.scanner-hint,
.scanner-inline-error {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 12px 0 0;
  color: var(--color-muted);
  font-size: 13px;
  line-height: 1.5;
}

.scanner-inline-error {
  color: var(--color-danger);
}

.scanner-reader {
  display: grid;
  place-items: center;
  min-height: 360px;
  overflow: hidden;
  border: 1px dashed var(--color-border-strong);
  border-radius: 18px;
  background: #101318;
}

.scanner-reader--active {
  border-style: solid;
}

.scanner-reader__placeholder {
  display: grid;
  gap: 8px;
  max-width: 260px;
  padding: 24px;
  color: #fff;
  text-align: center;
}

.scanner-reader__placeholder span:last-child {
  color: rgba(255, 255, 255, 0.68);
  font-size: 13px;
  line-height: 1.5;
}

.scanner-reader__icon {
  font-size: 46px;
  line-height: 1;
}

.scanner-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 14px;
}

.scanner-result {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 18px;
}

.scanner-result--success {
  border-color: rgba(16, 124, 65, 0.25);
  background: var(--color-success-soft);
}

.scanner-result--failure {
  border-color: rgba(180, 35, 24, 0.22);
  background: var(--color-danger-soft);
}

.scanner-result__icon {
  display: grid;
  place-items: center;
  width: 58px;
  height: 58px;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.08);
  font-size: 32px;
  font-weight: 800;
}

.scanner-result__copy {
  display: grid;
  gap: 5px;
}

.scanner-result__copy > strong {
  font-size: 16px;
}

.scanner-result__copy > span {
  color: var(--color-muted);
  font-size: 13px;
}

@media (max-width: 900px) {
  .scanner-grid {
    grid-template-columns: 1fr;
  }

  .scanner-panel--camera {
    grid-row: auto;
  }
}

@media (max-width: 620px) {
  .scanner-panel,
  .scanner-result {
    padding: 16px;
    border-radius: 16px;
  }

  .scanner-reader {
    min-height: 300px;
  }

  .scanner-result {
    grid-template-columns: auto minmax(0, 1fr);
  }

  .scanner-result .admin-button {
    grid-column: 1 / -1;
    width: 100%;
  }
}
</style>
