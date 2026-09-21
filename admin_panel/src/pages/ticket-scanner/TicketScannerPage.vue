<template>
  <PageShell
    eyebrow="Операционный вход"
    title="Сканер входа"
    description="Проверяйте QR-код билета или абонемента перед входом. Без связи вход не считается подтверждённым."
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
          :disabled="isOperator || isRedeeming || isScannerActive"
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

        <div class="scanner-lookup">
          <div class="scanner-section-heading">
            <div>
              <p class="scanner-eyebrow">Резервный поиск</p>
              <h2>Не получается показать QR?</h2>
            </div>
          </div>
          <form class="scanner-lookup__form" @submit.prevent="runLookup">
            <input
              v-model="lookupQuery"
              class="admin-control"
              type="search"
              placeholder="Номер заказа или телефон"
              aria-label="Номер заказа или телефон"
            />
            <button class="admin-button admin-button--secondary" type="submit" :disabled="lookupLoading || !lookupQuery.trim()">
              {{ lookupLoading ? 'Ищем…' : 'Найти' }}
            </button>
          </form>
          <p v-if="lookupError" class="scanner-inline-error">{{ lookupError }}</p>
          <div v-if="lookupResults.length" class="scanner-lookup__results">
            <article v-for="order in lookupResults" :key="order.paymentId" class="scanner-lookup__order">
              <strong>{{ order.localOrderId }}</strong>
              <span>{{ order.phone || 'Телефон не указан' }} · {{ order.branchName }}</span>
              <span v-for="ticket in order.tickets" :key="ticket.ticketId">
                {{ ticket.title }} · {{ ticket.status === 'used' ? 'использован' : 'готов к входу' }}
                <button
                  v-if="ticket.status === 'issued'"
                  type="button"
                  class="admin-button admin-button--ghost scanner-lookup__manual"
                  :disabled="manualRedeemingTicketId === ticket.ticketId || !selectedBranchId"
                  @click="redeemManually(ticket.ticketId)"
                >
                  {{ manualRedeemingTicketId === ticket.ticketId ? 'Проводим…' : 'Провести вручную' }}
                </button>
              </span>
            </article>
          </div>
          <p v-else-if="lookupDone" class="scanner-hint">Оплаченный заказ не найден.</p>
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
        <div class="scanner-result__icon" :aria-label="resultTitle" role="img">{{ resultIcon }}</div>
        <div class="scanner-result__copy">
          <p class="scanner-eyebrow scanner-result__outcome">{{ resultOutcomeLabel }}</p>
          <h2>{{ resultTitle }}</h2>
          <template v-if="result.ticket">
            <strong class="scanner-result__ticket-number">{{ result.ticket.ticketNumber }}</strong>
            <span class="scanner-result__ticket-type">{{ result.ticket.title }}</span>
            <span class="scanner-result__detail">Филиал: {{ result.ticket.branchName }}</span>
            <span class="scanner-result__detail">Статус: {{ formatTicketStatus(result.ticket.status) }}</span>
            <span v-if="result.ticket.redeemedAt" class="scanner-result__detail">
              Время входа: {{ formatDateTime(result.ticket.redeemedAt) }}
            </span>
          </template>
          <template v-if="result.pass">
            <strong class="scanner-result__ticket-number">{{ result.pass.planName || 'Абонемент' }}</strong>
            <span v-if="result.pass.childName" class="scanner-result__detail">Ребёнок: {{ result.pass.childName }}</span>
            <span v-if="result.pass.remainingVisits !== null" class="scanner-result__detail">
              Осталось посещений: {{ result.pass.remainingVisits }}{{ result.pass.visitLimit !== null ? ` из ${result.pass.visitLimit}` : '' }}
            </span>
            <span v-if="result.pass.branchName" class="scanner-result__detail">Филиал: {{ result.pass.branchName }}</span>
            <span v-if="result.pass.expiresAt" class="scanner-result__detail">Действует до: {{ formatDateTime(result.pass.expiresAt) }}</span>
          </template>
          <span v-if="result.errorMessage" class="scanner-result__reason">{{ result.errorMessage }}</span>
        </div>
        <button
          v-if="!isRedeeming"
          type="button"
          class="admin-button admin-button--primary"
          @click="scanNext"
        >
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
import {
  redeemTicket,
  redeemAdmission,
  resolveRedemptionOutcome,
  type TicketRedemptionResponse,
  type AdmissionResponse,
  lookupTickets,
  redeemTicketManually,
} from '@/features/ticket-scanner/api/ticketRedemptionApi';
import {
  listScannerBranches,
  type ScannerBranch,
} from '@/features/ticket-scanner/api/publicBranchesApi';
import PageShell from '@/shared/ui/PageShell.vue';
import { resolveAdminRequestError } from '@/features/auth/lib/adminRequest';

const sessionStore = useSessionStore();
const branches = ref<ScannerBranch[]>([]);
const selectedBranchId = ref(sessionStorage.getItem('boom-bala.scanner.branch-id') ?? '');
const readerElement = ref<HTMLElement | null>(null);
const branchesLoading = ref(false);
const branchesError = ref('');
const cameraError = ref('');
const isScannerActive = ref(false);
const isRedeeming = ref(false);
const lookupQuery = ref('');
const lookupLoading = ref(false);
const lookupDone = ref(false);
const lookupError = ref('');
const lookupResults = ref<Awaited<ReturnType<typeof lookupTickets>>>([]);
const manualRedeemingTicketId = ref('');
const result = ref<{
  outcome: string;
  ticket: TicketRedemptionResponse | null;
  pass: AdmissionResponse | null;
  kindHint: AdmissionKindHint;
  errorMessage: string;
} | null>(null);
let scanner: Html5Qrcode | null = null;
let scanLocked = false;

const selectedBranch = computed(() => branches.value.find((branch) => branch.id === selectedBranchId.value));
const isOperator = computed(() => sessionStore.operatorRole === 'operator');
const resultToneClass = computed(() => {
  if (result.value?.outcome === 'checking') return 'scanner-result--checking';
  if (result.value?.outcome === 'redeemed') return 'scanner-result--success';
  if (result.value?.outcome === 'already_used' || result.value?.outcome === 'already_used_today') return 'scanner-result--warning';
  return 'scanner-result--failure';
});
const resultOutcomeLabel = computed(() => {
  if (result.value?.outcome === 'checking') return 'Проверяем';
  if (result.value?.outcome === 'redeemed') return 'Успешно';
  if (result.value?.outcome === 'already_used' || result.value?.outcome === 'already_used_today') return 'Проверка завершена';
  return 'Вход не подтверждён';
});
const resultTitle = computed(() => {
  switch (result.value?.outcome) {
    case 'checking':
      return 'QR считан. Проверяем…';
    case 'redeemed':
      return 'Вход подтверждён';
    case 'already_used':
      return result.value?.pass || result.value?.kindHint === 'pass'
        ? 'Абонемент уже использован сегодня'
        : 'Билет уже использован';
    case 'already_used_today':
      return 'Абонемент уже использован сегодня';
    case 'invalid_qr':
      return 'Неверный QR';
    case 'ticket_not_found':
      return 'Билет не найден';
    case 'wrong_branch':
      return result.value?.pass || result.value?.kindHint === 'pass'
        ? 'Абонемент недоступен в этом филиале'
        : 'Билет относится к другому филиалу';
    case 'wrong_date':
      return 'Билет на другую дату';
    case 'invalid_status':
      return result.value?.pass || result.value?.kindHint === 'pass'
        ? 'Абонемент недействителен'
        : 'Билет недействителен';
    case 'expired':
      return 'Абонемент истёк';
    case 'exhausted':
      return 'Посещения абонемента закончились';
    case 'cancelled':
      return 'Абонемент отменён';
    case 'invalid_ticket_data':
      return 'Ошибка данных билета';
    case 'invalid_payment':
      return 'Оплата не подтверждена';
    default:
      return 'Нет связи. Вход не подтверждён.';
  }
});
const resultIcon = computed(() => {
  if (result.value?.outcome === 'checking') return '…';
  if (result.value?.outcome === 'redeemed') return '✓';
  if (result.value?.outcome === 'already_used' || result.value?.outcome === 'already_used_today') return '⚠';
  return '!';
});
let nextScanTimer: number | undefined;

type AdmissionKindHint = 'ticket' | 'pass' | 'unknown';

function admissionKindHint(qrPayload: string): AdmissionKindHint {
  if (qrPayload.startsWith('bb_ticket:v1:')) return 'ticket';
  if (qrPayload.startsWith('bb_pass:v1:')) return 'pass';
  return 'unknown';
}

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
  if (nextScanTimer !== undefined) window.clearTimeout(nextScanTimer);
  void stopScanner();
});

async function loadBranches() {
  branchesLoading.value = true;
  branchesError.value = '';
  try {
    const availableBranches = await listScannerBranches();
    if (isOperator.value) {
      const assignedBranchId = sessionStore.currentUser?.branch_id;
      branches.value = assignedBranchId
        ? availableBranches.filter((branch) => branch.id === assignedBranchId)
        : [];
      if (!assignedBranchId) {
        branchesError.value = 'Вам не назначен активный филиал.';
      } else if (branches.value.length === 0) {
        branchesError.value = 'Назначенный филиал неактивен или недоступен.';
      }
      selectedBranchId.value = branches.value[0]?.id ?? '';
    } else {
      branches.value = availableBranches;
    }
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

async function runLookup() {
  if (!lookupQuery.value.trim()) return;
  lookupLoading.value = true;
  lookupDone.value = false;
  lookupError.value = '';
  lookupResults.value = [];
  try {
    lookupResults.value = await lookupTickets(lookupQuery.value);
  } catch (error) {
    lookupError.value = resolveAdminRequestError(error, 'Не удалось выполнить поиск.');
  } finally {
    lookupLoading.value = false;
    lookupDone.value = true;
  }
}

async function redeemManually(ticketId: string) {
  if (!selectedBranchId.value || manualRedeemingTicketId.value) return;
  const reason = window.prompt(
    'Причина: customer_device_unavailable, qr_unavailable или support_override',
    'qr_unavailable',
  );
  if (!reason || !['customer_device_unavailable', 'qr_unavailable', 'support_override'].includes(reason)) {
    lookupError.value = 'Укажите разрешённую причину ручного входа.';
    return;
  }
  if (!window.confirm(`Провести билет вручную? Причина: ${reason}`)) {
    return;
  }
  manualRedeemingTicketId.value = ticketId;
  lookupError.value = '';
  try {
    await redeemTicketManually({
      ticketId,
      branchId: selectedBranchId.value,
      reason: reason as 'customer_device_unavailable' | 'qr_unavailable' | 'support_override',
    });
    await runLookup();
  } catch (error) {
    lookupError.value = resolveAdminRequestError(error, 'Не удалось провести билет вручную.');
  } finally {
    manualRedeemingTicketId.value = '';
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
  const kindHint = admissionKindHint(decodedText);
  result.value = {
    outcome: 'checking',
    ticket: null,
    pass: null,
    kindHint,
    errorMessage: '',
  };
  await stopScanner();
  try {
    const response = await redeemAdmission({ qrPayload: decodedText, branchId: selectedBranchId.value });
    result.value = {
      outcome: response.outcome,
      ticket: response.kind === 'ticket'
        ? {
            outcome: response.outcome as TicketRedemptionResponse['outcome'],
            ticketId: response.ticketId ?? '',
            ticketNumber: response.ticketNumber ?? '',
            title: 'Билет',
            branchId: response.branchId,
            branchName: response.branchName,
            visitDate: null,
            status: response.outcome === 'redeemed' || response.outcome === 'already_used'
              ? 'used'
              : response.status ?? 'issued',
            redeemedAt: response.redeemedAt,
            visitId: response.visitId,
          }
        : null,
      pass: response.kind === 'pass' ? response : null,
      kindHint: response.kind,
      errorMessage: '',
    };
    notifyRedemptionOutcome(response.outcome);
  } catch (error) {
    result.value = {
      outcome: resolveRedemptionOutcome(error),
      ticket: null,
      pass: null,
      kindHint,
      errorMessage: resolveScannerError(error, kindHint),
    };
  } finally {
    isRedeeming.value = false;
    scheduleNextScan();
  }
}

async function scanNext() {
  if (nextScanTimer !== undefined) {
    window.clearTimeout(nextScanTimer);
    nextScanTimer = undefined;
  }
  result.value = null;
  scanLocked = false;
  await startScanner();
}

function scheduleNextScan() {
  if (nextScanTimer !== undefined) window.clearTimeout(nextScanTimer);
  nextScanTimer = window.setTimeout(() => {
    nextScanTimer = undefined;
    if (!isRedeeming.value && !isScannerActive.value && result.value) {
      void scanNext();
    }
  }, 3500);
}

function notifyRedemptionOutcome(outcome: string) {
  if (outcome !== 'redeemed') return;
  navigator.vibrate?.([80, 40, 120]);
}

function resolveScannerError(error: unknown, kindHint: AdmissionKindHint = 'unknown') {
  const outcome = resolveRedemptionOutcome(error);
  switch (outcome) {
    case 'invalid_qr':
      return 'QR-код не распознан или его подпись недействительна.';
    case 'ticket_not_found':
      return 'Билет не найден.';
    case 'wrong_branch':
      return kindHint === 'pass'
        ? 'Абонемент недоступен в этом филиале.'
        : 'Билет относится к другому филиалу.';
    case 'wrong_date':
      return 'Билет действителен на другую дату.';
    case 'invalid_status':
      return 'Билет недействителен или уже закрыт.';
    case 'invalid_ticket_data':
      return 'В данных билета не хватает информации для входа.';
    case 'invalid_payment':
      return 'Оплата билета не подтверждена.';
    case 'already_used_today':
      return 'Абонемент уже использован сегодня.';
    case 'expired':
      return 'Срок действия абонемента истёк.';
    case 'exhausted':
      return 'Посещения по абонементу закончились.';
    case 'cancelled':
      return 'Абонемент отменён.';
    case 'pass_not_found':
      return 'Абонемент не найден.';
    case 'network_error':
      return 'Нет связи. Вход не подтверждён.';
    default:
      return resolveAdminRequestError(error, 'Вход не подтверждён.');
  }
}

function formatTicketStatus(status: string) {
  switch (status.toLowerCase()) {
    case 'used':
      return 'Погашен · USED';
    case 'issued':
      return 'Действует';
    case 'canceled':
      return 'Отменён';
    case 'refunded':
      return 'Возвращён';
    default:
      return status;
  }
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

.scanner-result--checking {
  border-color: rgba(39, 91, 160, 0.24);
  background: rgba(39, 91, 160, 0.07);
}

.scanner-result--warning {
  border-color: rgba(154, 103, 0, 0.3);
  background: #fff8e1;
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

.scanner-result--success .scanner-result__icon {
  color: var(--color-success);
  background: rgba(16, 124, 65, 0.14);
}

.scanner-result--checking .scanner-result__icon {
  color: var(--color-accent);
  background: rgba(39, 91, 160, 0.12);
}

.scanner-result--warning .scanner-result__icon {
  color: #9a6700;
  background: rgba(154, 103, 0, 0.14);
}

.scanner-result--failure .scanner-result__icon {
  color: var(--color-danger);
  background: rgba(180, 35, 24, 0.12);
}

.scanner-result__copy {
  display: grid;
  gap: 5px;
}

.scanner-result__copy > strong {
  font-size: 16px;
}

.scanner-result__outcome {
  margin-bottom: 0;
}

.scanner-result--success h2 {
  color: var(--color-success);
  font-size: 28px;
}

.scanner-result--checking h2 {
  color: var(--color-accent);
}

.scanner-result--warning h2 {
  color: #9a6700;
}

.scanner-result--failure h2 {
  color: var(--color-danger);
}

.scanner-result__ticket-number {
  font-size: 20px !important;
  letter-spacing: 0.02em;
}

.scanner-result__ticket-type,
.scanner-result__detail,
.scanner-result__reason {
  color: var(--color-muted);
  font-size: 13px;
}

.scanner-result__reason {
  color: var(--color-danger);
  font-weight: 700;
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
