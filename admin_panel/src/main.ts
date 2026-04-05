import { createPinia } from 'pinia';
import { createApp } from 'vue';

import App from './App.vue';
import router from './app/router';
import './app/styles/main.css';

const app = createApp(App);

app.use(createPinia());
app.use(router);
app.mount('#app');

