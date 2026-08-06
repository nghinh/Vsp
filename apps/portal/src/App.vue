<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { getSession, hasAnyRole, signOut } from './auth';
import {
  COURSE_ROLES,
  GREENKEEPING_ROLES,
  CORRECTION_ROLES,
  DATA_QUALITY_ROLES,
  TOURNAMENT_ROLES,
  SUPER_ADMIN_ONLY,
  type RoleName,
} from './roles';

const route = useRoute();
const router = useRouter();
const pageTitle = computed(() => String(route.meta.title ?? 'Tổng quan vận hành'));

/**
 * The navigation, with the roles each entry needs — the same lists the routes
 * carry, so the sidebar cannot offer a link the guard will bounce.
 *
 * `roles: undefined` means any operator: reaching the shell at all requires a
 * session, and a session requires at least one role.
 */
const navigation: { label: string; icon: string; to: string; roles?: readonly RoleName[] }[] = [
  { label: 'Tổng quan', icon: 'dashboard', to: '/dashboard' },
  { label: 'Cơ sở & Sân', icon: 'golf_course', to: '/facilities', roles: COURSE_ROLES },
  { label: 'Biên tập bản đồ', icon: 'map', to: '/map-editor', roles: COURSE_ROLES },
  { label: 'Vị trí cắm cờ', icon: 'keep', to: '/pin-positions', roles: GREENKEEPING_ROLES },
  { label: 'Tình trạng sân', icon: 'thermostat', to: '/course-conditions', roles: GREENKEEPING_ROLES },
  { label: 'Cảnh báo', icon: 'warning', to: '/alerts', roles: COURSE_ROLES },
  { label: 'Hiệu chỉnh', icon: 'edit_notifications', to: '/corrections', roles: CORRECTION_ROLES },
  { label: 'Chất lượng dữ liệu', icon: 'fact_check', to: '/admin/data-quality', roles: DATA_QUALITY_ROLES },
  { label: 'Giải đấu', icon: 'emoji_events', to: '/tournaments', roles: TOURNAMENT_ROLES },
  { label: 'Thị trường & Tích hợp', icon: 'public', to: '/market-integrations', roles: SUPER_ADMIN_ONLY },
  { label: 'Người dùng & Vai trò', icon: 'group', to: '/users', roles: SUPER_ADMIN_ONLY },
];

/** Recomputed per route change, which is also when a session can have appeared. */
const visibleNavigation = computed(() => {
  void route.fullPath;
  return navigation.filter((item) => hasAnyRole(item.roles));
});

const session = computed(() => {
  void route.fullPath;
  return getSession();
});

/**
 * The sidebar used to read `Nguyễn Hồng Nghi / Course Admin`, hard-coded in the
 * template, whoever was looking at it.
 */
const operatorName = computed(() => session.value?.displayName ?? '');
const operatorRoles = computed(() => session.value?.roles.join(' · ') ?? '');
const operatorInitials = computed(() =>
  operatorName.value
    .split(/\s+/)
    .filter(Boolean)
    .slice(-2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join(''),
);

const isSignedIn = computed(() => session.value !== null);

async function onSignOut() {
  signOut();
  await router.replace('/login');
}
</script>

<template>
  <!-- The sign-in screen is not part of the operations shell: there is no
       operator, no navigation to filter and nothing to show in the sidebar. -->
  <RouterView v-if="!isSignedIn" />
  <div v-else class="app-shell">
    <aside class="sidebar">
      <div class="brand-block">
        <span class="material-symbols-outlined brand-icon">sports_golf</span>
        <div><strong>GolfOps Portal</strong><small>Course Operations</small></div>
      </div>
      <nav aria-label="Điều hướng chính">
        <RouterLink v-for="item in visibleNavigation" :key="item.to" :to="item.to">
          <span class="material-symbols-outlined">{{ item.icon }}</span>
          <span>{{ item.label }}</span>
        </RouterLink>
      </nav>
      <div class="sidebar-footer">
        <div class="system-state"><span></span><div><strong>Hệ thống hoạt động</strong><small>Dữ liệu vừa đồng bộ</small></div></div>
        <div class="operator">
          <div class="avatar">{{ operatorInitials }}</div>
          <div><strong>{{ operatorName }}</strong><small>{{ operatorRoles }}</small></div>
          <button class="sign-out" type="button" aria-label="Đăng xuất" @click="onSignOut">
            <span class="material-symbols-outlined">logout</span>
          </button>
        </div>
      </div>
    </aside>
    <section class="workspace">
      <header class="topbar">
        <div><p>Vietnam Smart Golf</p><h1>{{ pageTitle }}</h1></div>
        <div class="topbar-actions">
          <button class="icon-button" aria-label="Tìm kiếm"><span class="material-symbols-outlined">search</span></button>
          <button class="icon-button has-dot" aria-label="Thông báo"><span class="material-symbols-outlined">notifications</span></button>
          <div class="sync-pill"><span></span> Đồng bộ</div>
        </div>
      </header>
      <main class="content"><RouterView /></main>
    </section>
  </div>
</template>

<style scoped>
.operator {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.sign-out {
  margin-left: auto;
  display: grid;
  place-items: center;
  padding: 0.35rem;
  border: none;
  border-radius: 0.5rem;
  background: transparent;
  color: inherit;
  opacity: 0.7;
  cursor: pointer;
}

.sign-out:hover {
  opacity: 1;
}
</style>
