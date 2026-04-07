<template>
  <PageShell :eyebrow="eyebrow" :title="title" :description="description">
    <template #actions>
      <button
        v-if="actionLabel"
        type="button"
        class="admin-button admin-button--primary"
      >
        {{ actionLabel }}
      </button>
    </template>

    <div class="preview-layout">
      <section class="admin-panel admin-panel--stack">
        <div class="admin-section-heading">
          <h2>{{ listTitle }}</h2>
        </div>

        <label class="admin-field">
          <span class="admin-field__label">Поиск</span>
          <input
            v-model="searchQuery"
            type="search"
            class="admin-control"
            :placeholder="searchPlaceholder"
          />
        </label>

        <StatePanel
          v-if="normalizedItems.length === 0"
          title="Список пока пуст"
          :description="emptyDescription"
        />

        <StatePanel
          v-else-if="filteredItems.length === 0"
          title="Ничего не найдено"
          description="Измените поисковый запрос, чтобы снова увидеть записи в этом разделе."
        />

        <div v-else class="preview-records">
          <button
            v-for="item in filteredItems"
            :key="item.id"
            type="button"
            class="preview-record"
            :class="{ 'preview-record--active': item.id === selectedItem?.id }"
            @click="selectedId = item.id"
          >
            <span class="preview-record__accent" aria-hidden="true"></span>
            <div class="preview-record__copy">
              <strong class="preview-record__label">{{ item.label }}</strong>
              <p v-if="item.summary" class="preview-record__summary">{{ item.summary }}</p>
            </div>
            <StatusBadge
              :label="item.statusLabel"
              :tone="item.statusTone"
            />
          </button>
        </div>
      </section>

      <aside class="admin-panel admin-panel--stack">
        <StatePanel
          v-if="normalizedItems.length === 0"
          :title="emptyTitle"
          :description="emptyDescription"
        />

        <StatePanel
          v-else-if="!selectedItem"
          title="Выберите запись слева"
          description="Подробности и рабочие действия откроются справа после выбора записи."
        />

        <template v-else>
          <header class="preview-detail__header">
            <div class="preview-detail__copy">
              <p class="preview-detail__eyebrow">Карточка записи</p>
              <div class="preview-detail__title-row">
                <h2>{{ selectedItem.label }}</h2>
                <StatusBadge
                  :label="selectedItem.statusLabel"
                  :tone="selectedItem.statusTone"
                />
              </div>
              <p class="preview-detail__description">
                {{ selectedItem.summary || detailDescription }}
              </p>
            </div>
          </header>

          <article class="preview-detail-card">
            <div class="admin-section-heading">
              <h3>Следующий шаг</h3>
            </div>
            <p class="admin-copy-muted">
              {{ selectedItem.note || note }}
            </p>
          </article>
        </template>
      </aside>
    </div>
  </PageShell>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';

import PageShell from '@/shared/ui/PageShell.vue';
import StatePanel from '@/shared/ui/StatePanel.vue';
import StatusBadge from '@/shared/ui/StatusBadge.vue';

type PreviewItem = {
  id: string;
  label: string;
  summary?: string;
  note?: string;
  statusLabel?: string;
  statusTone?: 'neutral' | 'new' | 'in-progress' | 'closed' | 'warning' | 'danger';
};

type NormalizedPreviewItem = Omit<PreviewItem, 'statusLabel' | 'statusTone'> & {
  statusLabel: string;
  statusTone: 'neutral' | 'new' | 'in-progress' | 'closed' | 'warning' | 'danger';
};

const props = withDefaults(
  defineProps<{
    eyebrow?: string;
    title: string;
    description: string;
    items: Array<string | PreviewItem>;
    note: string;
    listTitle?: string;
    emptyTitle?: string;
    emptyDescription?: string;
    actionLabel?: string;
    rowMetaLabel?: string;
    rowMetaTone?: 'neutral' | 'new' | 'in-progress' | 'closed' | 'warning' | 'danger';
    searchPlaceholder?: string;
    detailDescription?: string;
  }>(),
  {
    eyebrow: '',
    listTitle: 'Список записей',
    emptyTitle: 'Данных пока нет',
    emptyDescription: 'Создайте первую запись, чтобы сотрудники могли работать с этим разделом.',
    actionLabel: 'Добавить запись',
    rowMetaLabel: 'Черновик',
    rowMetaTone: 'neutral',
    searchPlaceholder: 'Найти запись',
    detailDescription: 'Подробности выбранной записи будут показаны здесь.',
  },
);

const searchQuery = ref('');
const selectedId = ref('');

const normalizedItems = computed<NormalizedPreviewItem[]>(() => {
  return props.items.map((item, index) => {
    if (typeof item === 'string') {
      return {
        id: `preview-${index}`,
        label: item,
        statusLabel: props.rowMetaLabel,
        statusTone: props.rowMetaTone,
      };
    }

    return {
      ...item,
      statusLabel: item.statusLabel ?? props.rowMetaLabel,
      statusTone: item.statusTone ?? props.rowMetaTone,
    };
  });
});

const filteredItems = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) {
    return normalizedItems.value;
  }

  return normalizedItems.value.filter((item) => {
    return `${item.label} ${item.summary ?? ''}`.toLowerCase().includes(query);
  });
});

const selectedItem = computed<NormalizedPreviewItem | null>(() => {
  return (
    filteredItems.value.find((item) => item.id === selectedId.value) ??
    filteredItems.value[0] ??
    null
  );
});

watch(
  filteredItems,
  (items) => {
    if (items.length === 0) {
      selectedId.value = '';
      return;
    }

    if (!items.some((item) => item.id === selectedId.value)) {
      selectedId.value = items[0].id;
    }
  },
  { immediate: true },
);
</script>

<style scoped>
.preview-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.08fr) minmax(320px, 0.92fr);
  gap: 16px;
}

.preview-records {
  display: grid;
  gap: 8px;
}

.preview-record {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  min-height: 56px;
  padding: 0 14px 0 16px;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-surface);
  text-align: left;
  cursor: pointer;
  transition:
    border-color 120ms ease,
    background-color 120ms ease,
    box-shadow 120ms ease;
}

.preview-record:hover {
  border-color: var(--color-border-strong);
  background: var(--color-surface-subtle);
}

.preview-record--active {
  border-color: rgba(208, 47, 112, 0.24);
  background: #fffafd;
  box-shadow: 0 8px 20px rgba(208, 47, 112, 0.08);
}

.preview-record__accent {
  position: absolute;
  inset: 8px auto 8px 0;
  width: 3px;
  border-radius: 999px;
  background: transparent;
}

.preview-record--active .preview-record__accent {
  background: var(--color-accent);
}

.preview-record__copy {
  display: grid;
  gap: 3px;
  min-width: 0;
}

.preview-record__label {
  font-size: 14px;
  line-height: 1.25;
}

.preview-record__summary,
.preview-detail__description {
  margin: 0;
  color: var(--color-muted);
  line-height: 1.45;
}

.preview-record__summary {
  font-size: 13px;
}

.preview-detail__header {
  display: grid;
  gap: 8px;
}

.preview-detail__copy {
  display: grid;
  gap: 6px;
}

.preview-detail__eyebrow {
  margin: 0;
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.preview-detail__title-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
}

.preview-detail__title-row h2 {
  margin: 0;
  font-size: 20px;
  line-height: 1.2;
}

.preview-detail-card {
  display: grid;
  gap: 10px;
  padding: 14px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface-subtle);
}

@media (max-width: 1100px) {
  .preview-layout {
    grid-template-columns: 1fr;
  }
}
</style>
