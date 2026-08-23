<script setup lang="ts">
/**
 * Where the router guard sends an operator who is signed in but does not hold
 * a role the route requires.
 *
 * It says so rather than redirecting quietly to the dashboard: an auditor who
 * follows a link to /users has not made a mistake worth hiding, and a silent
 * redirect reads as a broken link. The API would refuse the page's requests
 * either way — this is the portal agreeing with it out loud.
 */
import { getSession } from '@/auth';

const session = getSession();
</script>

<template>
  <section class="forbidden">
    <span class="material-symbols-outlined">lock</span>
    <h2>Không đủ quyền</h2>
    <p>Mục này yêu cầu vai trò mà tài khoản của bạn không có.</p>
    <p v-if="session?.roles.length" class="roles">
      Vai trò hiện tại: <strong>{{ session.roles.join(', ') }}</strong>
    </p>
    <RouterLink to="/dashboard">Về tổng quan</RouterLink>
  </section>
</template>

<style scoped>
.forbidden {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.6rem;
  padding: 2rem;
}

.forbidden h2 {
  margin: 0;
}

.forbidden p {
  margin: 0;
  opacity: 0.8;
}

.roles {
  font-size: 0.85rem;
}

.forbidden a {
  margin-top: 0.5rem;
  color: var(--primary-bright);
  font-weight: 600;
}
</style>
