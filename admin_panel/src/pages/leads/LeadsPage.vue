<template>
  <PageShell
    eyebrow="Lead inbox"
    title="Customer requests"
    description="Operational inbox for birthday requests with staff-side filters, detail review, and status changes on the real backend."
  >
    <template #actions>
      <button
        type="button"
        class="secondary-button"
        :disabled="leadInbox.isListLoading"
        @click="leadInbox.loadLeads"
      >
        {{ leadInbox.isListLoading ? 'Refreshing...' : 'Refresh inbox' }}
      </button>
    </template>

    <div class="lead-inbox">
      <form class="filters" @submit.prevent="leadInbox.loadLeads">
        <label class="field">
          <span>Branch</span>
          <select
            v-model="leadInbox.filters.branchId"
            :disabled="leadInbox.isListLoading || leadInbox.isBranchesLoading"
          >
            <option value="">All branches</option>
            <option
              v-for="branch in leadInbox.branchOptions"
              :key="branch.id"
              :value="branch.id"
            >
              {{ branch.shortLabel }}
            </option>
          </select>
        </label>

        <label class="field">
          <span>Status</span>
          <select v-model="leadInbox.filters.status" :disabled="leadInbox.isListLoading">
            <option value="">All statuses</option>
            <option
              v-for="status in leadStatuses"
              :key="status"
              :value="status"
            >
              {{ formatStatus(status) }}
            </option>
          </select>
        </label>

        <label class="field">
          <span>Created from</span>
          <input
            v-model="leadInbox.filters.createdFrom"
            type="date"
            :disabled="leadInbox.isListLoading"
          />
        </label>

        <label class="field">
          <span>Created to</span>
          <input
            v-model="leadInbox.filters.createdTo"
            type="date"
            :disabled="leadInbox.isListLoading"
          />
        </label>

        <div class="filter-actions">
          <button
            type="submit"
            class="primary-button"
            :disabled="leadInbox.isListLoading"
          >
            {{ leadInbox.isListLoading ? 'Loading...' : 'Apply filters' }}
          </button>
          <button
            type="button"
            class="secondary-button"
            :disabled="leadInbox.isListLoading || !leadInbox.hasActiveFilters"
            @click="leadInbox.resetFilters"
          >
            Reset
          </button>
        </div>
      </form>

      <p v-if="leadInbox.branchesErrorMessage" class="inline-error">
        {{ leadInbox.branchesErrorMessage }}
      </p>

      <div class="inbox-meta">
        <p class="summary">{{ totalLabel }}</p>
      </div>

      <div class="content-grid">
        <section class="list-panel">
          <div v-if="leadInbox.isListLoading" class="state-block">
            Loading leads...
          </div>
          <div v-else-if="leadInbox.listErrorMessage" class="state-block state-block-error">
            {{ leadInbox.listErrorMessage }}
          </div>
          <div v-else-if="leadInbox.leads.length === 0" class="state-block">
            No leads match the current filters.
          </div>
          <div v-else class="list">
            <button
              v-for="lead in leadInbox.leads"
              :key="lead.id"
              type="button"
              class="row"
              :class="{ 'row-active': lead.id === leadInbox.selectedLeadId }"
              @click="leadInbox.selectLead(lead.id)"
            >
              <div class="row-head">
                <div>
                  <strong>{{ lead.customerName }}</strong>
                  <p>
                    {{ lead.branch.shortLabel }} · {{ formatLeadType(lead.type) }}
                  </p>
                </div>
                <span class="status" :data-status="lead.status">
                  {{ formatStatus(lead.status) }}
                </span>
              </div>

              <dl class="row-facts">
                <div>
                  <dt>Phone</dt>
                  <dd>{{ lead.phone }}</dd>
                </div>
                <div>
                  <dt>Guests</dt>
                  <dd>{{ formatGuestCount(lead.guestCount) }}</dd>
                </div>
                <div>
                  <dt>Requested date</dt>
                  <dd>{{ formatDate(lead.requestedDate) }}</dd>
                </div>
                <div>
                  <dt>Created</dt>
                  <dd>{{ formatDateTime(lead.createdAt) }}</dd>
                </div>
              </dl>
            </button>
          </div>
        </section>

        <aside class="detail-panel">
          <div v-if="!leadInbox.selectedLeadId" class="state-block">
            Select a lead to review the request details and update its status.
          </div>
          <div
            v-else-if="leadInbox.isDetailLoading && !leadInbox.selectedLead"
            class="state-block"
          >
            Loading lead details...
          </div>
          <div
            v-else-if="leadInbox.detailErrorMessage"
            class="state-block state-block-error"
          >
            {{ leadInbox.detailErrorMessage }}
          </div>
          <template v-else-if="leadInbox.selectedLead">
            <header class="detail-header">
              <div>
                <p class="detail-eyebrow">Lead detail</p>
                <h3>{{ leadInbox.selectedLead.customerName }}</h3>
                <p class="detail-description">
                  {{ leadInbox.selectedLead.branch.name }}
                  <span v-if="leadInbox.selectedLead.package">
                    · {{ leadInbox.selectedLead.package.name }}
                  </span>
                </p>
              </div>
              <span class="status" :data-status="leadInbox.selectedLead.status">
                {{ formatStatus(leadInbox.selectedLead.status) }}
              </span>
            </header>

            <section class="status-actions">
              <div class="status-actions-header">
                <div>
                  <p class="section-label">Status</p>
                  <p class="status-hint">
                    {{
                      leadInbox.isStatusUpdating
                        ? 'Updating current request...'
                        : 'Use the operational lifecycle for this lead.'
                    }}
                  </p>
                </div>
              </div>

              <div class="status-buttons">
                <button
                  v-for="status in leadStatuses"
                  :key="status"
                  type="button"
                  class="status-button"
                  :class="{
                    'status-button-active': status === leadInbox.selectedLead.status,
                  }"
                  :disabled="leadInbox.isStatusUpdating"
                  @click="leadInbox.updateLeadStatus(status)"
                >
                  {{ formatStatus(status) }}
                </button>
              </div>

              <p v-if="leadInbox.statusSuccessMessage" class="inline-success">
                {{ leadInbox.statusSuccessMessage }}
              </p>
              <p v-if="leadInbox.statusErrorMessage" class="inline-error">
                {{ leadInbox.statusErrorMessage }}
              </p>
            </section>

            <div class="detail-grid">
              <article class="detail-card">
                <h4>Contact</h4>
                <dl>
                  <div>
                    <dt>Phone</dt>
                    <dd>{{ leadInbox.selectedLead.phone }}</dd>
                  </div>
                  <div>
                    <dt>Contact method</dt>
                    <dd>{{ formatContactMethod(leadInbox.selectedLead.contactMethod) }}</dd>
                  </div>
                  <div>
                    <dt>Source</dt>
                    <dd>{{ formatSource(leadInbox.selectedLead.source) }}</dd>
                  </div>
                </dl>
              </article>

              <article class="detail-card">
                <h4>Request</h4>
                <dl>
                  <div>
                    <dt>Guests</dt>
                    <dd>{{ formatGuestCount(leadInbox.selectedLead.guestCount) }}</dd>
                  </div>
                  <div>
                    <dt>Requested date</dt>
                    <dd>{{ formatDate(leadInbox.selectedLead.requestedDate) }}</dd>
                  </div>
                  <div>
                    <dt>Created at</dt>
                    <dd>{{ formatDateTime(leadInbox.selectedLead.createdAt) }}</dd>
                  </div>
                </dl>
              </article>

              <article class="detail-card detail-card-full">
                <h4>Notes</h4>
                <p class="notes-copy">
                  {{ leadInbox.selectedLead.notes || 'No notes were submitted for this request.' }}
                </p>
              </article>
            </div>
          </template>
        </aside>
      </div>
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive } from 'vue';

import { leadStatuses, type LeadStatus, type LeadType } from '@/entities/lead/model/lead';
import { useLeadInbox } from '@/features/leads/model/useLeadInbox';
import PageShell from '@/shared/ui/PageShell.vue';

const leadInbox = reactive(useLeadInbox());

const totalLabel = computed(() => {
  const count = leadInbox.total;
  return `${count} request${count === 1 ? '' : 's'} in inbox`;
});

onMounted(() => {
  void leadInbox.initialize();
});

function formatStatus(status: LeadStatus): string {
  return status
    .split('_')
    .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
    .join(' ');
}

function formatLeadType(type: LeadType): string {
  if (type === 'birthday_request') {
    return 'Birthday request';
  }

  return type;
}

function formatDate(value: string | null): string {
  if (!value) {
    return 'Not specified';
  }

  return new Intl.DateTimeFormat('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(new Date(`${value}T00:00:00`));
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function formatGuestCount(value: number | null): string {
  if (!value) {
    return 'Not specified';
  }

  return `${value} guest${value === 1 ? '' : 's'}`;
}

function formatContactMethod(value: string): string {
  return value
    .split('_')
    .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
    .join(' ');
}

function formatSource(value: string): string {
  return value
    .split('_')
    .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
    .join(' ');
}
</script>

<style scoped>
.lead-inbox {
  display: grid;
  gap: 18px;
}

.filters {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr)) auto;
  gap: 14px;
  align-items: end;
}

.field {
  display: grid;
  gap: 8px;
}

.field span,
.section-label,
.detail-eyebrow {
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-accent);
}

.field input,
.field select,
.primary-button,
.secondary-button,
.status-button {
  border-radius: 14px;
  padding: 12px 14px;
  font: inherit;
}

.field input,
.field select {
  border: 1px solid var(--color-border);
  background: #fff;
}

.filter-actions {
  display: flex;
  gap: 12px;
}

.primary-button,
.secondary-button,
.status-button {
  border: 1px solid var(--color-border);
  cursor: pointer;
}

.primary-button {
  background: var(--color-accent);
  color: #fff;
  border-color: transparent;
}

.secondary-button,
.status-button {
  background: #fff;
  color: var(--color-text);
}

.primary-button:disabled,
.secondary-button:disabled,
.status-button:disabled {
  opacity: 0.7;
  cursor: wait;
}

.inbox-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.summary {
  margin: 0;
  color: var(--color-muted);
}

.content-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.3fr) minmax(320px, 0.9fr);
  gap: 18px;
}

.list-panel,
.detail-panel {
  min-width: 0;
}

.list {
  display: grid;
  gap: 12px;
}

.row {
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 14px;
  width: 100%;
  padding: 18px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: #fff;
  text-align: left;
  cursor: pointer;
  transition: border-color 120ms ease, transform 120ms ease, box-shadow 120ms ease;
}

.row:hover,
.row-active {
  border-color: rgba(228, 107, 22, 0.32);
  box-shadow: var(--shadow-soft);
  transform: translateY(-1px);
}

.row-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.row p,
.detail-description,
.status-hint,
.notes-copy {
  margin: 6px 0 0;
  color: var(--color-muted);
}

.row-facts,
.detail-card dl {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin: 0;
}

.row-facts dt,
.detail-card dt {
  font-size: 12px;
  color: var(--color-muted);
}

.row-facts dd,
.detail-card dd {
  margin: 4px 0 0;
  font-weight: 600;
}

.status {
  align-self: flex-start;
  border-radius: 999px;
  padding: 8px 12px;
  background: var(--color-accent-soft);
}

.status[data-status='in_progress'] {
  background: #ffefc2;
}

.status[data-status='closed'] {
  background: #e7efe4;
}

.detail-panel {
  display: grid;
}

.detail-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 20px;
}

.detail-header h3,
.detail-card h4 {
  margin: 0;
}

.status-actions {
  display: grid;
  gap: 12px;
  margin-bottom: 20px;
  padding: 18px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.6);
}

.status-actions-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.status-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.status-button-active {
  border-color: rgba(228, 107, 22, 0.32);
  background: var(--color-accent-soft);
}

.detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.detail-card {
  padding: 18px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: #fff;
}

.detail-card-full {
  grid-column: 1 / -1;
}

.state-block {
  display: grid;
  place-items: center;
  min-height: 240px;
  padding: 24px;
  border: 1px dashed var(--color-border);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.56);
  color: var(--color-muted);
  text-align: center;
}

.state-block-error,
.inline-error {
  color: #b64040;
}

.inline-error,
.inline-success {
  margin: 0;
}

.inline-success {
  color: #2f7a40;
}

@media (max-width: 1280px) {
  .filters {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .filter-actions {
    grid-column: 1 / -1;
  }

  .content-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .filters,
  .row-facts,
  .detail-card dl,
  .detail-grid {
    grid-template-columns: 1fr;
  }

  .filter-actions {
    flex-direction: column;
  }

  .row-head,
  .detail-header {
    flex-direction: column;
  }
}
</style>
