import { computed, onBeforeUnmount, onMounted, ref } from 'vue';

function createMediaMatcher(query: string) {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') {
    return null;
  }

  return window.matchMedia(query);
}

export function useAdminViewport() {
  const width = ref<number>(typeof window === 'undefined' ? 1440 : window.innerWidth);

  function updateWidth() {
    if (typeof window !== 'undefined') {
      width.value = window.innerWidth;
    }
  }

  onMounted(() => {
    updateWidth();
    window.addEventListener('resize', updateWidth, { passive: true });
  });

  onBeforeUnmount(() => {
    if (typeof window !== 'undefined') {
      window.removeEventListener('resize', updateWidth);
    }
  });

  const isMobile = computed(() => width.value < 768);
  const isTablet = computed(() => width.value >= 768 && width.value < 1280);
  const isDesktop = computed(() => width.value >= 1280);

  return {
    width,
    isMobile,
    isTablet,
    isDesktop,
    matches(query: string) {
      return Boolean(createMediaMatcher(query)?.matches);
    },
  };
}
