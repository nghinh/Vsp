<script setup lang="ts">
/**
 * Operations landing page.
 *
 * This was 333 lines of literal arrays and made no API call at all: "03 sân cần
 * xác minh", "12 hiệu chỉnh chờ xử lý", "02 cảnh báo đang hoạt động", "18 vị trí
 * cờ sắp tới", plus a course-health table naming real Vietnamese courses with
 * invented statuses ("Quá hạn 2h", "Đã cập nhật"). None of it came from
 * anywhere. It was the first screen an operator saw after signing in, and every
 * number on it was made up — including two that claimed active safety alerts.
 *
 * It is now a way in to the sections that work, and it says plainly that the
 * operational counters are not wired yet. The counters are a real piece of
 * work: a dashboard endpoint that aggregates corrections, data quality, pins
 * and alerts does not exist on the server either.
 */
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { getSession, hasAnyRole } from '../../auth';
import {
  COURSE_ROLES,
  CORRECTION_ROLES,
  DATA_QUALITY_ROLES,
  TOURNAMENT_ROLES,
  type RoleName,
} from '../../roles';

const router = useRouter();

const greeting = computed(() => {
  const h = new Date().getHours();
  if (h < 11) return 'Chào buổi sáng';
  if (h < 14) return 'Chào buổi trưa';
  if (h < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
});

const operatorName = computed(() => getSession()?.displayName ?? 'bạn');

/** Only the destinations that actually read from the API. */
const sections: {
  label: string;
  description: string;
  icon: string;
  to: string;
  roles?: readonly RoleName[];
}[] = [
  {
    label: 'Cơ sở & Sân',
    description: 'Quản lý cơ sở, sân, hố và bộ điểm phát bóng',
    icon: 'golf_course',
    to: '/facilities',
    roles: COURSE_ROLES,
  },
  {
    label: 'Biên tập bản đồ',
    description: 'Vẽ và chỉnh sửa hình học sân, phát hành phiên bản',
    icon: 'map',
    to: '/map-editor',
    roles: COURSE_ROLES,
  },
  {
    label: 'Hiệu chỉnh',
    description: 'Duyệt báo lỗi dữ liệu golfer gửi lên',
    icon: 'edit_notifications',
    to: '/corrections',
    roles: CORRECTION_ROLES,
  },
  {
    label: 'Chất lượng dữ liệu',
    description: 'Độ phủ hình học, sân đã xác minh, thời gian xử lý',
    icon: 'fact_check',
    to: '/admin/data-quality',
    roles: DATA_QUALITY_ROLES,
  },
  {
    label: 'Giải đấu',
    description: 'Cấu hình giải, thể lệ và bảng xếp hạng',
    icon: 'emoji_events',
    to: '/tournaments',
    roles: TOURNAMENT_ROLES,
  },
];

const visibleSections = computed(() =>
  sections.filter((s) => !s.roles || hasAnyRole(s.roles)),
);
</script>

<template>
  <div class="dashboard">
    <header class="head">
      <h1>{{ greeting }}, {{ operatorName }}</h1>
      <p class="sub">Chọn một mục để bắt đầu.</p>
    </header>

    <p class="notice" role="status">
      <span class="material-symbols-outlined">info</span>
      Các chỉ số vận hành tổng hợp chưa được nối với máy chủ nên chưa hiển thị ở
      đây. Trước đây trang này hiện những con số dựng sẵn — kể cả số cảnh báo an
      toàn đang hoạt động — và không con số nào lấy từ dữ liệu thật.
    </p>

    <ul class="sections">
      <li v-for="section in visibleSections" :key="section.to">
        <button type="button" class="section" @click="router.push(section.to)">
          <span class="material-symbols-outlined icon">{{ section.icon }}</span>
          <span class="text">
            <span class="label">{{ section.label }}</span>
            <span class="description">{{ section.description }}</span>
          </span>
          <span class="material-symbols-outlined chevron">chevron_right</span>
        </button>
      </li>
    </ul>
  </div>
</template>

<style scoped>
.dashboard {
  padding: 1.5rem;
  max-width: 56rem;
}

.head h1 {
  margin: 0;
  font-size: 1.5rem;
}

.sub {
  margin: 0.25rem 0 0;
  color: var(--vsp-text-muted, #94a3b8);
}

.notice {
  display: flex;
  gap: 0.5rem;
  align-items: flex-start;
  margin: 1.5rem 0;
  padding: 0.875rem 1rem;
  border: 1px solid var(--vsp-border, #334155);
  border-radius: 10px;
  background: var(--vsp-surface-muted, #1e293b);
  font-size: 0.875rem;
  color: var(--vsp-text-muted, #94a3b8);
}

.sections {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.75rem;
}

.section {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 0.875rem;
  padding: 1rem;
  border: 1px solid var(--vsp-border, #334155);
  border-radius: 12px;
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
  min-height: 44px;
}

.section:hover,
.section:focus-visible {
  border-color: var(--vsp-primary, #ea580c);
}

.text {
  display: flex;
  flex-direction: column;
  flex: 1;
}

.label {
  font-weight: 600;
}

.description {
  font-size: 0.8125rem;
  color: var(--vsp-text-muted, #94a3b8);
}

.chevron {
  color: var(--vsp-text-muted, #94a3b8);
}
</style>
