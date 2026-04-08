import { computed, ref } from 'vue';
import { defineStore } from 'pinia';

export const useSessionStore = defineStore('session', () => {
  const operatorEmail = ref('');
  const isAuthenticated = computed(() => operatorEmail.value.length > 0);

  function signIn(email: string) {
    operatorEmail.value = email.trim();
  }

  function signOut() {
    operatorEmail.value = '';
  }

  return {
    operatorEmail,
    isAuthenticated,
    signIn,
    signOut,
  };
});

