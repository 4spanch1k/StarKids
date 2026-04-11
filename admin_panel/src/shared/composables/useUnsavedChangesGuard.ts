import { onBeforeUnmount, onMounted } from 'vue';
import { onBeforeRouteLeave } from 'vue-router';

export function useUnsavedChangesGuard(
  isDirty: () => boolean,
  message = 'Есть несохраненные изменения. Закрыть без сохранения?',
) {
  function confirmLeave() {
    if (!isDirty()) {
      return true;
    }

    return window.confirm(message);
  }

  function handleBeforeUnload(event: BeforeUnloadEvent) {
    if (!isDirty()) {
      return;
    }

    event.preventDefault();
    event.returnValue = message;
  }

  onMounted(() => {
    window.addEventListener('beforeunload', handleBeforeUnload);
  });

  onBeforeUnmount(() => {
    window.removeEventListener('beforeunload', handleBeforeUnload);
  });

  onBeforeRouteLeave(() => {
    return confirmLeave();
  });

  return {
    confirmLeave,
  };
}
