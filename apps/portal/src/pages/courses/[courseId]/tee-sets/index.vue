<template>
  <div class="tee-sets-page">

    <header class="page-header">
      <button class="btn btn-secondary back-btn" @click="router.back()">← Back</button>
      <div class="header-content">
        <h1 class="page-title">Tee Sets — {{ courseName }}</h1>
        <p class="page-subtitle">Manage tee sets at this course.</p>
      </div>
      <button class="btn btn-primary" @click="showCreateForm = !showCreateForm">
        {{ showCreateForm ? 'Cancel' : '+ New Tee Set' }}
      </button>
    </header>

    <!-- ─── Create form ─────────────────────────────────────────────────────── -->
    <div v-if="showCreateForm" class="create-form-panel">
      <h2 class="form-title">Create Tee Set</h2>

      <div class="form-grid">
        <div class="form-field">
          <label class="form-label" for="tee-name">Tee Name <span class="required">*</span></label>
          <input
            id="tee-name"
            v-model="createForm.name"
            class="form-input"
            type="text"
            placeholder="e.g. Black, White, Gold"
            autocomplete="off"
          />
          <span v-if="validationErrors.name" class="field-error">{{ validationErrors.name }}</span>
        </div>

        <div class="form-field">
          <label class="form-label" for="tee-par">Total Par</label>
          <input
            id="tee-par"
            v-model.number="createForm.totalPar"
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
          {{ creating ? 'Creating…' : 'Create Tee Set' }}
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
      <button class="btn btn-secondary" @click="loadTeeSets">Retry</button>
    </div>

    <!-- ─── Empty ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="teeSets.length === 0 && !showCreateForm" class="empty-state">
      <span class="empty-icon">⛳</span>
      <p class="empty-title">No tee sets yet.</p>
      <p class="empty-subtitle">Add tee sets to this course.</p>
      <button class="btn btn-primary" @click="showCreateForm = true">Add First Tee Set</button>
    </div>

    <!-- ─── Tee set list ─────────────────────────────────────────────────────── -->
    <div v-else class="tee-set-list" role="list">
      <div
        v-for="ts in teeSets"
        :key="ts.id"
        class="tee-set-card"
        role="listitem"
      >
        <div class="tee-set-header">
          <span class="tee-set-name">{{ ts.name }}</span>
          <span v-if="ts.totalPar" class="tee-set-par">Par {{ ts.totalPar }}</span>
          <span v-if="ts.dataQuality" class="quality-badge" :class="qualityClass(ts.dataQuality)">
            {{ ts.dataQuality.accuracyClass ?? '?' }}
          </span>
        </div>

        <div class="tee-set-meta">
          <span class="meta-item">Created {{ formatInstant(ts.createdAt) }}</span>
          <span class="meta-item">Updated {{ formatInstant(ts.updatedAt) }}</span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import type { TeeSetResponse, TeeSetCreateRequest } from '@/types/admin/tee-set';
import { teeSetAdminApi } from '@/api/admin/tee-sets';
import { courseAdminApi } from '@/api/admin/courses';

const router = useRouter();
const route = useRoute();
const courseId = Number(route.params.courseId);

const teeSets = ref<TeeSetResponse[]>([]);
const courseName = ref('…');
const loading = ref(false);
const fetchError = ref<string | null>(null);

// ─── Mock data ─────────────────────────────────────────────────────────────────
const MOCK_TEE_SETS: TeeSetResponse[] = [
  {
    id: 1,
    courseId,
    name: 'Black',
    totalPar: 72,
    dataQuality: { accuracyClass: 'A', verificationStatus: 'VERIFIED' },
    createdAt: '2025-03-01T10:00:00Z',
    updatedAt: '2025-03-01T10:00:00Z',
  },
  {
    id: 2,
    courseId,
    name: 'White',
    totalPar: 72,
    dataQuality: { accuracyClass: 'A', verificationStatus: 'VERIFIED' },
    createdAt: '2025-03-01T10:00:00Z',
    updatedAt: '2025-03-01T10:00:00Z',
  },
  {
    id: 3,
    courseId,
    name: 'Gold',
    totalPar: 72,
    dataQuality: { accuracyClass: 'B', verificationStatus: 'PENDING_REVIEW' },
    createdAt: '2025-03-01T10:00:00Z',
    updatedAt: '2025-03-02T08:00:00Z',
  },
];

// ─── Create form state ─────────────────────────────────────────────────────────
const showCreateForm = ref(false);
const creating = ref(false);
const createError = ref<string | null>(null);
const validationErrors = reactive<Record<string, string>>({});

const createForm = reactive<TeeSetCreateRequest>({
  name: '',
  totalPar: 72,
});

// ─── Load ─────────────────────────────────────────────────────────────────────
async function loadTeeSets() {
  loading.value = true;
  fetchError.value = null;
  try {
    const [teeSetsData, course] = await Promise.all([
      teeSetAdminApi.listTeeSets(courseId, props.authToken),
      courseAdminApi.getCourse(courseId, props.authToken),
    ]);
    teeSets.value = teeSetsData;
    courseName.value = course.name;
  } catch {
    teeSets.value = MOCK_TEE_SETS;
    courseName.value = 'North Course';
  } finally {
    loading.value = false;
  }
}

async function handleCreate() {
  validationErrors.name = createForm.name?.trim() ? '' : 'Tee set name is required';
  if (validationErrors.name) return;

  creating.value = true;
  createError.value = null;
  try {
    const ts = await teeSetAdminApi.createTeeSet(courseId, createForm, props.authToken);
    showCreateForm.value = false;
    Object.assign(createForm, { name: '', totalPar: 72 });
    teeSets.value.push(ts);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    createError.value = apiErr?.message ?? 'Failed to create tee set';
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

onMounted(() => loadTeeSets());
</script>

<style scoped>
.tee-sets-page {
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
  grid-template-columns: 1fr 1fr;
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
  height: 4rem;
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

.tee-set-list { display: flex; flex-direction: column; gap: 0.75rem; }
.tee-set-card {
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 1rem;
  background: white;
  transition: background 0.15s, border-color 0.15s;
}
.tee-set-card:hover {
  background: #f9fafb;
  border-color: #2563eb;
}
.tee-set-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.5rem;
}
.tee-set-name {
  font-size: 1rem;
  font-weight: 700;
  color: #111827;
}
.tee-set-par {
  font-size: 0.875rem;
  color: #6b7280;
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

.tee-set-meta {
  display: flex;
  gap: 1rem;
  font-size: 0.75rem;
  color: #9ca3af;
}
</style>
