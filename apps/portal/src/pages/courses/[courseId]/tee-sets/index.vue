<template>
  <div class="tee-sets-page">

    <header class="page-header">
      <button class="btn btn-secondary back-btn" @click="router.back()">← Quay lại</button>
      <div class="header-content">
        <h1 class="page-title">Bộ tee — {{ courseName }}</h1>
        <p class="page-subtitle">Quản lý bộ tee của sân này.</p>
      </div>
      <button class="btn btn-primary" @click="showCreateForm = !showCreateForm">
        {{ showCreateForm ? 'Huỷ' : '+ Thêm bộ tee' }}
      </button>
    </header>

    <!-- ─── Create form ─────────────────────────────────────────────────────── -->
    <div v-if="showCreateForm" class="create-form-panel">
      <h2 class="form-title">Tạo bộ tee</h2>

      <div class="form-grid">
        <div class="form-field">
          <label class="form-label" for="tee-name">Tên bộ tee <span class="required">*</span></label>
          <input
            id="tee-name"
            v-model="createForm.name"
            class="form-input"
            type="text"
            placeholder="ví dụ Black, White, Gold"
            autocomplete="off"
          />
          <span v-if="validationErrors.name" class="field-error">{{ validationErrors.name }}</span>
        </div>

        <div class="form-field">
          <label class="form-label" for="tee-par">Tổng par</label>
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
          {{ creating ? 'Đang tạo…' : 'Tạo bộ tee' }}
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
      <button class="btn btn-secondary" @click="loadTeeSets">Thử lại</button>
    </div>

    <!-- ─── Empty ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="teeSets.length === 0 && !showCreateForm" class="empty-state">
      <span class="empty-icon">⛳</span>
      <p class="empty-title">Chưa có bộ tee nào.</p>
      <p class="empty-subtitle">Thêm bộ tee cho sân này.</p>
      <button class="btn btn-primary" @click="showCreateForm = true">Thêm bộ tee đầu tiên</button>
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
          <span class="meta-item">Tạo lúc {{ formatInstant(ts.createdAt) }}</span>
          <span class="meta-item">Cập nhật {{ formatInstant(ts.updatedAt) }}</span>
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
import { formatDay as formatInstant } from '@/lib/datetime';

const router = useRouter();
const route = useRoute();
const courseId = Number(route.params.courseId);

const teeSets = ref<TeeSetResponse[]>([]);
const courseName = ref('…');
const loading = ref(false);
const fetchError = ref<string | null>(null);


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
  } catch (err: unknown) {
    // Was `teeSets.value = MOCK_TEE_SETS`, with fetchError left null — so an
    // operator whose API was down saw invented golf courses stamped
    // accuracyClass 'A' / VERIFIED, with no error banner, and every edit
    // targeted ids that do not exist. A missing danh sách điểm phát bóng is now a
    // missing danh sách điểm phát bóng.
    const apiErr = err as { message?: string };
    fetchError.value = apiErr?.message ?? 'Không tải được dữ liệu từ máy chủ.';
    teeSets.value = [];
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
    createError.value = apiErr?.message ?? 'Không tạo được bộ tee';
  } finally {
    creating.value = false;
  }
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
  border-bottom: 1px solid var(--surface-container-highest);
  padding-bottom: 1rem;
}
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
  height: 4rem;
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

.tee-set-list { display: flex; flex-direction: column; gap: 0.75rem; }
.tee-set-card {
  border: 1px solid var(--surface-container-highest);
  border-radius: 10px;
  padding: 1rem;
  background: var(--surface-container);
  transition: background 0.15s, border-color 0.15s;
}
.tee-set-card:hover {
  background: var(--surface-container);
  border-color: var(--primary-container);
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
  color: var(--on-surface);
}
.tee-set-par {
  font-size: 0.875rem;
  color: var(--muted);
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

.tee-set-meta {
  display: flex;
  gap: 1rem;
  font-size: 0.75rem;
  color: var(--muted);
}
</style>
