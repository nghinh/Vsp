<template>
  <div class="holes-page">

    <header class="page-header">
      <button class="btn btn-secondary back-btn" @click="router.back()">← Back</button>
      <div class="header-content">
        <h1 class="page-title">Holes — {{ courseName }}</h1>
        <p class="page-subtitle">Manage holes at this course.</p>
      </div>
      <button class="btn btn-primary" @click="showCreateForm = !showCreateForm">
        {{ showCreateForm ? 'Cancel' : '+ New Hole' }}
      </button>
    </header>

    <!-- ─── Create form ─────────────────────────────────────────────────────── -->
    <div v-if="showCreateForm" class="create-form-panel">
      <h2 class="form-title">Create Hole</h2>

      <div class="form-grid">
        <div class="form-field">
          <label class="form-label" for="hole-number">Hole Number <span class="required">*</span></label>
          <input
            id="hole-number"
            v-model.number="createForm.holeNumber"
            class="form-input"
            type="number"
            min="1"
            max="9"
            placeholder="1"
          />
          <span v-if="validationErrors.holeNumber" class="field-error">{{ validationErrors.holeNumber }}</span>
        </div>

        <div class="form-field">
          <label class="form-label" for="hole-par">Par <span class="required">*</span></label>
          <input
            id="hole-par"
            v-model.number="createForm.par"
            class="form-input"
            type="number"
            min="3"
            max="7"
            placeholder="4"
          />
          <span v-if="validationErrors.par" class="field-error">{{ validationErrors.par }}</span>
        </div>

        <div class="form-field">
          <label class="form-label" for="hole-length">Playing Length (meters)</label>
          <input
            id="hole-length"
            v-model.number="createForm.playingLengthMeters"
            class="form-input"
            type="number"
            min="50"
            max="700"
            placeholder="350"
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
          {{ creating ? 'Creating…' : 'Create Hole' }}
        </button>
      </div>
    </div>

    <!-- ─── Loading ──────────────────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true">
      <div v-for="i in 9" :key="i" class="skeleton-card" />
    </div>

    <!-- ─── Error ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="btn btn-secondary" @click="loadHoles">Retry</button>
    </div>

    <!-- ─── Empty ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="holes.length === 0 && !showCreateForm" class="empty-state">
      <span class="empty-icon">🏌️</span>
      <p class="empty-title">No holes yet.</p>
      <p class="empty-subtitle">Add holes to this course.</p>
      <button class="btn btn-primary" @click="showCreateForm = true">Add First Hole</button>
    </div>

    <!-- ─── Hole list ─────────────────────────────────────────────────────── -->
    <div v-else class="hole-list" role="list">
      <div
        v-for="hole in holes"
        :key="hole.id"
        class="hole-card"
        role="listitem"
      >
        <div class="hole-header">
          <span class="hole-number">Hole {{ hole.holeNumber }}</span>
          <span class="hole-par">Par {{ hole.par }}</span>
          <span v-if="hole.playingLengthMeters" class="hole-length">{{ hole.playingLengthMeters }}m</span>
          <span v-if="hole.teeBoxesCount" class="tee-boxes-count">{{ hole.teeBoxesCount }} tee boxes</span>
        </div>

        <div class="hole-meta">
          <span class="meta-item">Created {{ formatInstant(hole.createdAt) }}</span>
          <span v-if="hole.dataQuality" class="quality-badge" :class="qualityClass(hole.dataQuality)">
            {{ hole.dataQuality.accuracyClass ?? '?' }}
          </span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import type { HoleResponse, HoleCreateRequest } from '@/types/admin/hole';
import { holeAdminApi } from '@/api/admin/holes';
import { courseAdminApi } from '@/api/admin/courses';

const router = useRouter();
const route = useRoute();
const courseId = Number(route.params.courseId);

const holes = ref<HoleResponse[]>([]);
const courseName = ref('…');
const loading = ref(false);
const fetchError = ref<string | null>(null);

// ─── Mock data ─────────────────────────────────────────────────────────────────
const MOCK_HOLES: HoleResponse[] = Array.from({ length: 18 }, (_, i) => ({
  id: i + 1,
  courseId,
  holeNumber: (i % 9) + 1,
  par: [4, 4, 3, 5, 4, 4, 3, 5, 4][i % 9],
  teeingGroundLocation: null,
  greenLocation: null,
  playingLengthMeters: [350, 420, 150, 520, 380, 410, 180, 490, 360][i % 9],
  dataQuality: { accuracyClass: 'B', verificationStatus: 'VERIFIED' },
  teeBoxesCount: 4,
  createdAt: '2025-03-01T10:00:00Z',
  updatedAt: '2025-03-01T10:00:00Z',
}));

// ─── Create form state ─────────────────────────────────────────────────────────
const showCreateForm = ref(false);
const creating = ref(false);
const createError = ref<string | null>(null);
const validationErrors = reactive<Record<string, string>>({});

const createForm = reactive<HoleCreateRequest>({
  holeNumber: 1,
  par: 4,
  playingLengthMeters: undefined,
});

// ─── Load ─────────────────────────────────────────────────────────────────────
async function loadHoles() {
  loading.value = true;
  fetchError.value = null;
  try {
    const [holesData, course] = await Promise.all([
      holeAdminApi.listHoles(courseId, props.authToken),
      courseAdminApi.getCourse(courseId, props.authToken),
    ]);
    holes.value = holesData;
    courseName.value = course.name;
  } catch {
    holes.value = MOCK_HOLES;
    courseName.value = 'North Course';
  } finally {
    loading.value = false;
  }
}

async function handleCreate() {
  validationErrors.holeNumber = createForm.holeNumber ? '' : 'Hole number is required';
  validationErrors.par = createForm.par ? '' : 'Par is required';
  if (validationErrors.holeNumber || validationErrors.par) return;

  creating.value = true;
  createError.value = null;
  try {
    const hole = await holeAdminApi.createHole(courseId, createForm, props.authToken);
    showCreateForm.value = false;
    holes.value.push(hole);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    createError.value = apiErr?.message ?? 'Failed to create hole';
  } finally {
    creating.value = false;
  }
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

onMounted(() => loadHoles());
</script>

<style scoped>
.holes-page {
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
  border-bottom: 1px solid #2d3449;
  padding-bottom: 1rem;
}
.back-btn { align-self: center; }
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #dae2fd;
  margin: 0;
}
.page-subtitle {
  font-size: 0.875rem;
  color: #97a2c0;
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
  background: #f66018;
  color: white;
  border-color: #f66018;
}
.btn-primary:hover:not(:disabled) { background: #ec6a06; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary {
  background: #171f33;
  color: #c5cde8;
  border-color: #2d3449;
}
.btn-secondary:hover { background: #171f33; }

.create-form-panel {
  background: #171f33;
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 1.25rem;
  margin-bottom: 1.5rem;
}
.form-title {
  font-size: 1rem;
  font-weight: 600;
  color: #dae2fd;
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
  border: 1px solid #2d3449;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: #171f33;
  color: #dae2fd;
}
.form-input:focus {
  outline: none;
  border-color: #f66018;
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

.loading-state { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.75rem; }
.skeleton-card {
  height: 4rem;
  border-radius: 8px;
  background: linear-gradient(90deg, #2d3449 25%, #222a3d 50%, #2d3449 75%);
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
  color: #97a2c0;
  text-align: center;
}
.error-state { color: #dc2626; }
.empty-icon, .error-icon { font-size: 2rem; }
.empty-title { font-size: 1.125rem; font-weight: 600; margin: 0; }
.empty-subtitle { font-size: 0.875rem; color: #97a2c0; margin: 0; }

.hole-list { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.75rem; }
.hole-card {
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 0.875rem;
  background: #171f33;
  transition: background 0.15s, border-color 0.15s;
}
.hole-card:hover {
  background: #171f33;
  border-color: #f66018;
}
.hole-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-bottom: 0.5rem;
}
.hole-number {
  font-size: 0.875rem;
  font-weight: 700;
  color: #dae2fd;
}
.hole-par,
.hole-length {
  font-size: 0.75rem;
  color: #97a2c0;
}
.tee-boxes-count {
  font-size: 0.6875rem;
  padding: 0.1rem 0.4rem;
  border-radius: 9999px;
  background: #2d3449;
  color: #c5cde8;
  font-weight: 600;
}
.hole-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}
.meta-item { font-size: 0.6875rem; color: #97a2c0; }
.quality-badge {
  font-size: 0.625rem;
  font-weight: 700;
  padding: 0.1rem 0.4rem;
  border-radius: 9999px;
  border: 1px solid currentColor;
}
.badge-verified { color: #15803d; background: #dcfce7; }
.badge-pending  { color: #92400e; background: #fef3c7; }
.badge-unverified { color: #97a2c0; background: #222a3d; }
</style>
