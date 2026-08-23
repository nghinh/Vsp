<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { getSession, hasAnyRole, signOut } from './auth';
import { roleLabel } from './lib/enum-labels';
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
const operatorRoles = computed(
  () => session.value?.roles.map(roleLabel).join(' · ') ?? '',
);
const operatorInitials = computed(() =>
  operatorName.value
    .split(/\s+/)
    .filter(Boolean)
    .slice(-2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join(''),
);

const isSignedIn = computed(() => session.value !== null);

/**
 * Below 900px the sidebar becomes a drawer behind a menu button. It used to
 * shrink to a strip of unlabeled icons, then to a row of them above the page —
 * with the operator block, and with it the only sign-out button, hidden.
 */
const drawerOpen = ref(false);
watch(() => route.fullPath, () => { drawerOpen.value = false; });

async function onSignOut() {
  signOut();
  await router.replace('/login');
}
</script>

<template>
  <!-- The sign-in screen is not part of the operations shell: there is no
       operator, no navigation to filter and nothing to show in the sidebar. -->
  <RouterView v-if="!isSignedIn" />
  <div v-else class="app-shell" :class="{ 'drawer-open': drawerOpen }">
    <div class="drawer-backdrop" aria-hidden="true" @click="drawerOpen = false"></div>
    <aside id="portal-sidebar" class="sidebar">
      <div class="brand-block">
        <span class="material-symbols-outlined brand-icon">sports_golf</span>
        <div><strong>GolfOps Portal</strong><small>Course Operations</small></div>
        <button class="drawer-close" type="button" aria-label="Đóng menu" @click="drawerOpen = false">
          <span class="material-symbols-outlined">close</span>
        </button>
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
        <button
          class="menu-button"
          type="button"
          aria-label="Mở menu"
          aria-controls="portal-sidebar"
          :aria-expanded="drawerOpen"
          @click="drawerOpen = true"
        >
          <span class="material-symbols-outlined">menu</span>
        </button>
        <div class="topbar-title"><p>Vietnam Smart Golf</p><h1>{{ pageTitle }}</h1></div>
        <!--
          A search button, a notifications button carrying an unread dot, and a
          "Đồng bộ" pill used to sit here. None of them had a @click handler:
          the whole row was decoration, and the unread dot in particular told an
          operator there was something waiting for them that did not exist.
          Removed rather than stubbed — a control that does nothing is worse
          than no control, and these will come back when there is something
          behind them.
        -->
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
  min-width: 0;
}

.operator > div {
  min-width: 0;
}

.operator small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.operator .avatar {
  flex-shrink: 0;
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

.sign-out {
  flex-shrink: 0;
}

.sign-out:hover {
  opacity: 1;
}

.menu-button,
.drawer-close {
  display: none;
  place-items: center;
  width: 44px;
  height: 44px;
  padding: 0;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: transparent;
  color: inherit;
  cursor: pointer;
  flex-shrink: 0;
}

.drawer-close {
  margin-left: auto;
}

.drawer-backdrop {
  display: none;
}

@media (max-width: 900px) {
  .menu-button {
    display: grid;
  }
  .drawer-open .drawer-close {
    display: grid;
  }
  .drawer-backdrop {
    position: fixed;
    inset: 0;
    z-index: 19;
    display: block;
    background: rgba(0, 0, 0, 0.55);
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.2s;
  }
  .drawer-open .drawer-backdrop {
    opacity: 1;
    pointer-events: auto;
  }
}
</style>
