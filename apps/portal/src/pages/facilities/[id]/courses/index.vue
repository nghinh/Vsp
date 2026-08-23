<template>
  <div class="courses-page">

    <header class="page-header">
      <button class="btn btn-secondary back-btn" @click="router.back()">← Quay lại cơ sở</button>
      <div class="header-content">
        <h1 class="page-title">Các sân tại {{ facilityName }}</h1>
        <p class="page-subtitle">Quản lý các sân tại cơ sở này.</p>
      </div>
      <button class="btn btn-primary" @click="showCreateForm = !showCreateForm">
        {{ showCreateForm ? 'Huỷ' : '+ Tạo sân' }}
      </button>
    </header>

    <!-- ─── Create form ─────────────────────────────────────────────────────── -->
    <div v-if="showCreateForm" class="create-form-panel">
      <h2 class="form-title">Tạo sân golf</h2>

      <div class="form-grid">
        <div class="form-field">
          <label class="form-label" for="course-name">Tên sân <span class="required">*</span></label>
          <input
            id="course-name"
            v-model="createForm.name"
            class="form-input"
            type="text"
            placeholder="ví dụ Sân Bắc"
            autocomplete="off"
          />
          <span v-if="validationErrors.name" class="field-error">{{ validationErrors.name }}</span>
        </div>

        <div class="form-field">
          <label class="form-label" for="course-holes">Số hố</label>
          <input
            id="course-holes"
            v-model.number="createForm.holesCount"
            class="form-input"
            type="number"
            min="1"
            max="36"
            placeholder="18"
          />
          <span v-if="validationErrors.holesCount" class="field-error">{{ validationErrors.holesCount }}</span>
        </div>

        <div class="form-field">
          <label class="form-label" for="course-par">Tổng par</label>
          <input
            id="course-par"
            v-model.number="createForm.parTotal"
            class="form-input"
            type="number"
            min="18"
            max="144"
            placeholder="72"
          />
        </div>
      </div>

      <div class="form-actions">
        <span v-if="createError" class="error-message" role="alert">{{ createError }}</span>
        <button
          class="btn btn-primary"
          :disabled="creating"
          @click="handleCreate"
        >
          {{ creating ? 'Đang tạo…' : 'Tạo sân' }}
        </button>
      </div>
    </div>

    <!-- ─── Loading ──────────────────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true">
      <div v-for="i in 3" :key="i" class="skeleton-card" />
    </div>

    <!-- ─── Error ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="btn btn-secondary" @click="loadCourses">Thử lại</button>
    </div>

    <!-- ─── Empty ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="courses.length === 0 && !showCreateForm" class="empty-state">
      <span class="empty-icon">⛳</span>
      <p class="empty-title">Chưa có sân nào.</p>
      <p class="empty-subtitle">Thêm sân đầu tiên cho cơ sở này.</p>
      <button class="btn btn-primary" @click="showCreateForm = true">Thêm sân đầu tiên</button>
    </div>

    <!-- ─── Course list ─────────────────────────────────────────────────────── -->
    <div v-else class="course-list" role="list">
      <div
        v-for="course in courses"
        :key="course.id"
        class="course-card"
        role="listitem"
        @click="navigateToHoles(course.id)"
      >
        <div class="course-header">
          <span class="course-name" :class="{ retired: course.retiredOn }">{{ course.name }}</span>
          <!--
            An operator looking at Kings Island sees four courses while golfers
            are offered three. Without this there is nothing on screen that
            says why, and the missing one reads as a bug.
          -->
          <span
            v-if="course.retiredOn"
            class="retired-badge"
            :title="`Ngừng phục vụ từ ${course.retiredOn}. Sân và các hố vẫn được giữ — chỉ ẩn khỏi tìm kiếm và khỏi màn chọn sân khi mở vòng.`"
          >
            Ngừng phục vụ
          </span>
          <span v-if="course.dataQuality" class="quality-badge" :class="qualityClass(course.dataQuality)"
            :title="`${accuracyClassLabel(course.dataQuality.accuracyClass)} · ${verificationStatusLabel(course.dataQuality.verificationStatus)}`">
            {{ accuracyClassShort(course.dataQuality.accuracyClass) }}
          </span>
        </div>

        <div class="course-details">
          <span v-if="course.holesCount" class="detail-pill">{{ course.holesCount }} hố</span>
          <span v-if="course.parTotal" class="detail-pill">Par {{ course.parTotal }}</span>
          <span v-if="course.teeSets?.length" class="detail-pill">{{ course.teeSets.length }} bộ tee</span>
        </div>

        <div class="course-meta">
          <span class="meta-item">Tạo lúc {{ formatInstant(course.createdAt) }}</span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import type { CourseResponse, CourseCreateRequest } from '@/types/admin/course';
import { courseAdminApi } from '@/api/admin/courses';
import { facilityAdminApi } from '@/api/admin/facilities';
import { accuracyClassLabel, accuracyClassShort, verificationStatusLabel } from '@/lib/enum-labels';

const router = useRouter();
const route = useRoute();
const facilityId = Number(route.params.id);

const courses = ref<CourseResponse[]>([]);
const facilityName = ref('…');
const loading = ref(false);
const fetchError = ref<string | null>(null);


// ─── Create form state ─────────────────────────────────────────────────────────
const showCreateForm = ref(false);
const creating = ref(false);
const createError = ref<string | null>(null);
const validationErrors = reactive<Record<string, string>>({});

const createForm = reactive<CourseCreateRequest>({
  name: '',
  holesCount: 18,
  parTotal: 72,
});

// ─── Load ─────────────────────────────────────────────────────────────────────
async function loadCourses() {
  loading.value = true;
  fetchError.value = null;
  try {
    const [coursesData, facility] = await Promise.all([
      courseAdminApi.listCourses(facilityId, props.authToken),
      facilityAdminApi.getFacility(facilityId, props.authToken),
    ]);
    courses.value = coursesData;
    facilityName.value = facility.name;
  } catch (err: unknown) {
    // Was `courses.value = MOCK_COURSES`, with fetchError left null — so an
    // operator whose API was down saw invented golf courses stamped
    // accuracyClass 'A' / VERIFIED, with no error banner, and every edit
    // targeted ids that do not exist. A missing danh sách sân is now a
    // missing danh sách sân.
    const apiErr = err as { message?: string };
    fetchError.value = apiErr?.message ?? 'Không tải được dữ liệu từ máy chủ.';
    courses.value = [];
  } finally {
    loading.value = false;
  }
}

async function handleCreate() {
  validationErrors.name = createForm.name?.trim() ? '' : 'Course name is required';
  validationErrors.holesCount = !createForm.holesCount ? 'Phải nhập số hố' : '';
  if (validationErrors.name || validationErrors.holesCount) return;

  creating.value = true;
  createError.value = null;
  try {
    const course = await courseAdminApi.createCourse(facilityId, createForm, props.authToken);
    showCreateForm.value = false;
    Object.assign(createForm, { name: '', holesCount: 18, parTotal: 72 });
    router.push(`/courses/${course.id}/holes`);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    createError.value = apiErr?.message ?? 'Không tạo được sân';
  } finally {
    creating.value = false;
  }
}

function navigateToHoles(courseId: number) {
  router.push(`/courses/${courseId}/holes`);
}

function formatInstant(iso: string): string {
  return new Date(iso).toLocaleDateString();
}

function qualityClass(dq: { accuracyClass: string | null; verificationStatus: string | null }) {
  if (dq.verificationStatus === 'VERIFIED') return 'badge-verified';
  if (dq.verificationStatus === 'PENDING_REVIEW') return 'badge-pending';
  return 'badge-unverified';
}

const props = defineProps<{ authToken: string }>();

onMounted(() => loadCourses());
</script>

<style scoped>
.retired-badge {
  font-size: 0.7rem;
  font-weight: 700;
  color: #92400e;
  background: #fef3c7;
  border-radius: 0.25rem;
  padding: 0.1rem 0.4rem;
  margin-left: 0.5rem;
}

.course-name.retired {
  opacity: 0.6;
  text-decoration: line-through;
}

.courses-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 800px;
  margin: 0 auto;
}

.page-header {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
  border-bottom: 1px solid var(--surface-container-highest);
  padding-bottom: 1rem;
}
.header-content { flex: 1 1 200px; min-width: 0; }
.back-btn { align-self: center; }
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--on-surface);
  margin: 0;
}
.page-subtitle {
  font-size: 0.875rem;
  color: var(--muted);
  margin: 0.25rem 0 0;
}

.btn {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid transparent;
  min-height: 44px;
  transition: background 0.15s;
}
.btn-primary {
  background: var(--primary-container);
  color: white;
  border-color: var(--primary-container);
}
.btn-primary:hover:not(:disabled) { background: var(--secondary-container); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary {
  background: var(--surface-container);
  color: #c5cde8;
  border-color: var(--surface-container-highest);
}
.btn-secondary:hover { background: var(--surface-container); }

.create-form-panel {
  background: var(--surface-container);
  border: 1px solid var(--surface-container-highest);
  border-radius: 10px;
  padding: 1.25rem;
  margin-bottom: 1.5rem;
}
.form-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--on-surface);
  margin: 0 0 1rem;
}
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 1rem;
  margin-bottom: 1rem;
}
.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}
.form-label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: #c5cde8;
}
.required { color: #dc2626; }
.form-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--surface-container-highest);
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: var(--surface-container);
  color: var(--on-surface);
}
.form-input:focus {
  outline: none;
  border-color: var(--primary-container);
  box-shadow: 0 0 0 3px rgba(246, 96, 24, 0.1);
}
.field-error {
  font-size: 0.75rem;
  color: #dc2626;
  margin-top: 0.125rem;
}
.form-actions {
  display: flex;
  align-items: center;
  gap: 1rem;
  justify-content: flex-end;
}
.error-message {
  font-size: 0.875rem;
  color: #dc2626;
  margin-right: auto;
}

.loading-state { display: flex; flex-direction: column; gap: 0.75rem; }
.skeleton-card {
  height: 5rem;
  border-radius: 8px;
  background: linear-gradient(90deg, var(--surface-container-highest) 25%, var(--surface-container-high) 50%, var(--surface-container-highest) 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.error-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 1rem;
  color: var(--muted);
  text-align: center;
}
.error-state { color: #dc2626; }
.empty-icon, .error-icon { font-size: 2rem; }
.empty-title { font-size: 1.125rem; font-weight: 600; margin: 0; }
.empty-subtitle { font-size: 0.875rem; color: var(--muted); margin: 0; }

.course-list { display: flex; flex-direction: column; gap: 0.75rem; }
.course-card {
  border: 1px solid var(--surface-container-highest);
  border-radius: 10px;
  padding: 1rem;
  background: var(--surface-container);
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
.course-card:hover {
  background: var(--surface-container);
  border-color: var(--primary-container);
}
.course-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}
.course-name {
  font-size: 1rem;
  font-weight: 600;
  color: var(--on-surface);
}
.quality-badge {
  font-size: 0.6875rem;
  font-weight: 700;
  padding: 0.15rem 0.5rem;
  border-radius: 9999px;
  border: 1px solid currentColor;
}
.badge-verified { color: #15803d; background: #dcfce7; }
.badge-pending  { color: #92400e; background: #fef3c7; }
.badge-unverified { color: var(--muted); background: var(--surface-container-high); }

.course-details {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-bottom: 0.5rem;
}
.detail-pill {
  font-size: 0.6875rem;
  font-weight: 600;
  padding: 0.15rem 0.5rem;
  border-radius: 9999px;
  background: var(--surface-container-highest);
  color: #c5cde8;
}
.course-meta {
  display: flex;
  gap: 1rem;
  font-size: 0.75rem;
  color: var(--muted);
}

@media (max-width: 640px) {
  .header-content { flex-basis: 100%; order: -1; }
  .courses-page { padding: 0; }
  .page-header > .btn, .page-header > a.btn, .page-header > button { flex: 1 1 auto; text-align: center; }
  .form-grid { grid-template-columns: 1fr; }
}
</style>
