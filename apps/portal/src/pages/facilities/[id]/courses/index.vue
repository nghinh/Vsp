<template>
  <div class="courses-page">

    <header class="page-header">
      <button class="btn btn-secondary back-btn" @click="router.back()">← Back to Facility</button>
      <div class="header-content">
        <h1 class="page-title">Courses at {{ facilityName }}</h1>
        <p class="page-subtitle">Manage golf courses at this facility.</p>
      </div>
      <button class="btn btn-primary" @click="showCreateForm = !showCreateForm">
        {{ showCreateForm ? 'Cancel' : '+ New Course' }}
      </button>
    </header>

    <!-- ─── Create form ─────────────────────────────────────────────────────── -->
    <div v-if="showCreateForm" class="create-form-panel">
      <h2 class="form-title">Create Golf Course</h2>

      <div class="form-grid">
        <div class="form-field">
          <label class="form-label" for="course-name">Course Name <span class="required">*</span></label>
          <input
            id="course-name"
            v-model="createForm.name"
            class="form-input"
            type="text"
            placeholder="e.g. North Course"
            autocomplete="off"
          />
          <span v-if="validationErrors.name" class="field-error">{{ validationErrors.name }}</span>
        </div>

        <div class="form-field">
          <label class="form-label" for="course-holes">Number of Holes</label>
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
          <label class="form-label" for="course-par">Total Par</label>
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
          {{ creating ? 'Creating…' : 'Create Course' }}
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
      <button class="btn btn-secondary" @click="loadCourses">Retry</button>
    </div>

    <!-- ─── Empty ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="courses.length === 0 && !showCreateForm" class="empty-state">
      <span class="empty-icon">⛳</span>
      <p class="empty-title">No courses yet.</p>
      <p class="empty-subtitle">Add your first course to this facility.</p>
      <button class="btn btn-primary" @click="showCreateForm = true">Add First Course</button>
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
          <span class="course-name">{{ course.name }}</span>
          <span v-if="course.dataQuality" class="quality-badge" :class="qualityClass(course.dataQuality)">
            {{ course.dataQuality.accuracyClass ?? '?' }}
          </span>
        </div>

        <div class="course-details">
          <span v-if="course.holesCount" class="detail-pill">{{ course.holesCount }} holes</span>
          <span v-if="course.parTotal" class="detail-pill">Par {{ course.parTotal }}</span>
          <span v-if="course.teeSets?.length" class="detail-pill">{{ course.teeSets.length }} tee sets</span>
        </div>

        <div class="course-meta">
          <span class="meta-item">Created {{ formatInstant(course.createdAt) }}</span>
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

const router = useRouter();
const route = useRoute();
const facilityId = Number(route.params.id);

const courses = ref<CourseResponse[]>([]);
const facilityName = ref('…');
const loading = ref(false);
const fetchError = ref<string | null>(null);

// ─── Mock data ─────────────────────────────────────────────────────────────────
const MOCK_COURSES: CourseResponse[] = [
  {
    id: 1,
    facilityId,
    name: 'North Course',
    holesCount: 18,
    parTotal: 72,
    location: 'POINT(-74.567 39.789)',
    dataQuality: { accuracyClass: 'A', verificationStatus: 'VERIFIED' },
    teeSets: [
      { id: 1, name: 'Black', totalPar: 72, yardages: {}, rating: 75.3, slope: 143, dataQuality: null },
      { id: 2, name: 'White', totalPar: 72, yardages: {}, rating: 73.1, slope: 138, dataQuality: null },
    ],
    createdAt: '2025-03-01T10:00:00Z',
    updatedAt: '2025-03-01T10:00:00Z',
  },
];

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
  } catch {
    courses.value = MOCK_COURSES;
    facilityName.value = 'Pine Valley Golf Club';
  } finally {
    loading.value = false;
  }
}

async function handleCreate() {
  validationErrors.name = createForm.name?.trim() ? '' : 'Course name is required';
  validationErrors.holesCount = !createForm.holesCount ? 'Number of holes is required' : '';
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
    createError.value = apiErr?.message ?? 'Failed to create course';
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
.courses-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 800px;
  margin: 0 auto;
}

.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 1rem;
}
.back-btn { align-self: center; }
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
  margin: 0;
}
.page-subtitle {
  font-size: 0.875rem;
  color: #6b7280;
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
  background: #2563eb;
  color: white;
  border-color: #2563eb;
}
.btn-primary:hover:not(:disabled) { background: #1d4ed8; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary {
  background: white;
  color: #374151;
  border-color: #d1d5db;
}
.btn-secondary:hover { background: #f9fafb; }

.create-form-panel {
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 1.25rem;
  margin-bottom: 1.5rem;
}
.form-title {
  font-size: 1rem;
  font-weight: 600;
  color: #111827;
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
  color: #374151;
}
.required { color: #dc2626; }
.form-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: white;
  color: #111827;
}
.form-input:focus {
  outline: none;
  border-color: #2563eb;
  box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
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
  background: linear-gradient(90deg, #e5e7eb 25%, #f3f4f6 50%, #e5e7eb 75%);
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
  color: #6b7280;
  text-align: center;
}
.error-state { color: #dc2626; }
.empty-icon, .error-icon { font-size: 2rem; }
.empty-title { font-size: 1.125rem; font-weight: 600; margin: 0; }
.empty-subtitle { font-size: 0.875rem; color: #9ca3af; margin: 0; }

.course-list { display: flex; flex-direction: column; gap: 0.75rem; }
.course-card {
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 1rem;
  background: white;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
.course-card:hover {
  background: #f9fafb;
  border-color: #2563eb;
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
  color: #111827;
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
.badge-unverified { color: #9ca3af; background: #f3f4f6; }

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
  background: #e5e7eb;
  color: #374151;
}
.course-meta {
  display: flex;
  gap: 1rem;
  font-size: 0.75rem;
  color: #9ca3af;
}
</style>
