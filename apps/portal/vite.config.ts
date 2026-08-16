import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { fileURLToPath, URL } from 'node:url';

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    proxy: {
      // Where `/api` goes. A local API by default, and any deployment via
      // VSP_API_PROXY_TARGET.
      //
      // It was hard-coded at localhost:8080, which left exactly one way to
      // point the portal at a real server: set VITE_API_BASE_URL and have the
      // browser call it cross-origin. That does not work and cannot be made
      // to — the deployed API refuses a CORS preflight from a dev origin with
      // a 403, correctly, and the portal then reports the failure as a wrong
      // password. Proxying keeps every request same-origin, which is what the
      // portal is built for and what production does.
      '/api': {
        target: process.env.VSP_API_PROXY_TARGET ?? 'http://localhost:8080',
        changeOrigin: true,
        secure: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
});
