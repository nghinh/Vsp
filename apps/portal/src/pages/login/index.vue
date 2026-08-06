<script setup lang="ts">
/**
 * The portal's sign-in screen.
 *
 * There was not one. The portal declared itself SUPER_ADMIN in `auth.ts` and
 * sent `Bearer dev-portal-token` on every request, so there was nowhere for an
 * operator to say who they were and no token that any server would accept.
 */
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { signIn, signInErrorMessage } from '@/auth';

const route = useRoute();
const router = useRouter();

const identifier = ref('');
const password = ref('');
const error = ref('');
const busy = ref(false);

async function submit() {
  if (busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    await signIn(identifier.value.trim(), password.value);
    const target = typeof route.query.redirect === 'string' ? route.query.redirect : '/dashboard';
    await router.replace(target);
  } catch (e) {
    error.value = signInErrorMessage(e);
    password.value = '';
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="login-shell">
    <form class="login-card" @submit.prevent="submit">
      <div class="brand-block">
        <span class="material-symbols-outlined brand-icon">sports_golf</span>
        <div>
          <strong>GolfOps Portal</strong>
          <small>Course Operations</small>
        </div>
      </div>

      <h1>Đăng nhập</h1>
      <p class="hint">Dùng tài khoản vận hành đã được cấp vai trò.</p>

      <label>
        <span>Email hoặc số điện thoại</span>
        <input
          v-model="identifier"
          type="text"
          autocomplete="username"
          required
          :disabled="busy"
        />
      </label>

      <label>
        <span>Mật khẩu</span>
        <input
          v-model="password"
          type="password"
          autocomplete="current-password"
          required
          :disabled="busy"
        />
      </label>

      <p v-if="error" class="error" role="alert">{{ error }}</p>

      <button type="submit" :disabled="busy || !identifier || !password">
        {{ busy ? 'Đang kiểm tra…' : 'Đăng nhập' }}
      </button>
    </form>
  </div>
</template>

<style scoped>
.login-shell {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 2rem;
}

.login-card {
  width: min(24rem, 100%);
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 2rem;
  border-radius: 1rem;
  background: var(--surface, #171d2b);
  border: 1px solid var(--border, #26304a);
}

.login-card h1 {
  margin: 0;
  font-size: 1.4rem;
}

.hint {
  margin: 0;
  opacity: 0.7;
  font-size: 0.85rem;
}

.login-card label {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  font-size: 0.85rem;
}

.login-card input {
  padding: 0.6rem 0.75rem;
  border-radius: 0.5rem;
  border: 1px solid var(--border, #26304a);
  background: var(--surface-2, #0f1420);
  color: inherit;
}

.login-card button {
  margin-top: 0.5rem;
  padding: 0.7rem 1rem;
  border: none;
  border-radius: 0.5rem;
  background: var(--accent, #2f6fed);
  color: #fff;
  font-weight: 600;
  cursor: pointer;
}

.login-card button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error {
  margin: 0;
  color: #ff8a8a;
  font-size: 0.85rem;
}
</style>
