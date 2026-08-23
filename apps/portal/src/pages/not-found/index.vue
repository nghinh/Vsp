<script setup lang="ts">
/**
 * The page for a URL that matches no route.
 *
 * There was none: vue-router rendered nothing, so a broken link — and the
 * portal had several, to routes spelled from memory — ended on an empty
 * workspace under the default title, indistinguishable from a page still
 * loading.
 */
import { useRoute } from 'vue-router';

const route = useRoute();
</script>

<template>
  <section class="not-found">
    <span class="material-symbols-outlined" aria-hidden="true">link_off</span>
    <h2>Không có trang này</h2>
    <p>
      Đường dẫn <code>{{ route.fullPath }}</code> không trỏ tới màn hình nào của portal.
    </p>
    <RouterLink to="/dashboard">Về tổng quan</RouterLink>
  </section>
</template>

<style scoped>
.not-found {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.6rem;
  padding: 2rem;
}

.not-found h2,
.not-found p {
  margin: 0;
}

.not-found p {
  opacity: 0.8;
}

.not-found code {
  font-family: var(--font-mono);
  font-size: 0.9em;
}

.not-found a {
  margin-top: 0.5rem;
  color: var(--primary-bright);
  font-weight: 600;
}
</style>
