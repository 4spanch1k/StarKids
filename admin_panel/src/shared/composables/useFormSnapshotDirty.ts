import { computed, ref } from 'vue';

export function useFormSnapshotDirty<T>(source: () => T) {
  const snapshot = ref('');

  function serialize(value: T): string {
    return JSON.stringify(value ?? null);
  }

  function markClean() {
    snapshot.value = serialize(source());
  }

  const isDirty = computed(() => {
    return snapshot.value !== serialize(source());
  });

  return {
    isDirty,
    markClean,
  };
}
