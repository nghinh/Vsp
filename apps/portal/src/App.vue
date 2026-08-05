<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const pageTitle = computed(() => String(route.meta.title ?? 'Tổng quan vận hành'));

const navigation = [
  { label: 'Tổng quan', icon: 'dashboard', to: '/dashboard' },
  { label: 'Cơ sở & Sân', icon: 'golf_course', to: '/facilities' },
  { label: 'Biên tập bản đồ', icon: 'map', to: '/map-editor' },
  { label: 'Vị trí cắm cờ', icon: 'keep', to: '/pin-positions' },
  { label: 'Tình trạng sân', icon: 'thermostat', to: '/course-conditions' },
  { label: 'Cảnh báo', icon: 'warning', to: '/alerts' },
  { label: 'Hiệu chỉnh', icon: 'edit_notifications', to: '/corrections' },
  { label: 'Chất lượng dữ liệu', icon: 'fact_check', to: '/admin/data-quality' },
  { label: 'Giải đấu', icon: 'emoji_events', to: '/tournaments' },
  { label: 'Thị trường & Tích hợp', icon: 'public', to: '/market-integrations' },
  { label: 'Người dùng & Vai trò', icon: 'group', to: '/users' },
];
</script>

<template>
  <div class="app-shell">
    <aside class="sidebar">
      <div class="brand-block">
        <span class="material-symbols-outlined brand-icon">sports_golf</span>
        <div><strong>GolfOps Portal</strong><small>Course Operations</small></div>
      </div>
      <nav aria-label="Điều hướng chính">
        <RouterLink v-for="item in navigation" :key="item.to" :to="item.to">
          <span class="material-symbols-outlined">{{ item.icon }}</span>
          <span>{{ item.label }}</span>
        </RouterLink>
      </nav>
      <div class="sidebar-footer">
        <div class="system-state"><span></span><div><strong>Hệ thống hoạt động</strong><small>Dữ liệu vừa đồng bộ</small></div></div>
        <div class="operator"><div class="avatar">NH</div><div><strong>Nguyễn Hồng Nghi</strong><small>Course Admin</small></div></div>
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
