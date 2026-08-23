<template>
  <div class="tournament-policies-page">

    <header class="page-header">
      <div class="header-content">
        <h1 class="page-title">Chính sách giải đấu</h1>
        <p class="page-subtitle">Tạo và quản lý các hạn chế tính năng khi thi đấu.</p>
      </div>
      <button class="btn btn-primary" @click="showCreateForm = !showCreateForm">
        {{ showCreateForm ? 'Huỷ' : '+ Tạo thể lệ' }}
      </button>
    </header>

    <!-- ─── Create form ─────────────────────────────────────────────────────── -->
    <div v-if="showCreateForm" class="create-form-panel">
      <h2 class="form-title">Tạo chính sách giải</h2>

      <div class="form-grid">
        <!-- Name -->
        <div class="form-field">
          <label class="form-label" for="policy-name">Tên chính sách <span class="required">*</span></label>
          <input
            id="policy-name"
            v-model="createForm.name"
            class="form-input"
            type="text"
            placeholder="ví dụ Giải chính thức 2026"
            autocomplete="off"
          />
          <span v-if="validationErrors.name" class="field-error">{{ validationErrors.name }}</span>
        </div>

        <!-- Description -->
        <div class="form-field full-width">
          <label class="form-label" for="policy-desc">Mô tả</label>
          <textarea
            id="policy-desc"
            v-model="createForm.description"
            class="form-input"
            rows="2"
            placeholder="Mô tả khi nào dùng chính sách này (không bắt buộc)…"
          />
        </div>
      </div>

      <!-- Feature toggles -->
      <fieldset class="feature-group">
        <legend class="feature-group-title">Tính năng bật/tắt</legend>

        <div class="toggle-grid">
          <div v-for="flag in featureFlags" :key="flag.key" class="toggle-row">
            <div class="toggle-info">
              <span class="toggle-label">{{ flag.label }}</span>
              <span class="toggle-description">{{ flag.description }}</span>
            </div>
            <button
              class="toggle-btn"
              :class="getFlagValue(flag.key) ? 'toggle-on' : 'toggle-off'"
              role="switch"
              :aria-checked="getFlagValue(flag.key)"
              :aria-label="flag.label"
              @click="setFlag(flag.key, !getFlagValue(flag.key))"
            >
              <span class="toggle-thumb" />
            </button>
          </div>
        </div>
      </fieldset>

      <!-- Form actions -->
      <div class="form-actions">
        <span v-if="createError" class="error-message" role="alert">{{ createError }}</span>
        <button
          class="btn btn-primary"
          :disabled="creating"
          @click="handleCreate"
        >
          {{ creating ? 'Đang tạo…' : 'Tạo thể lệ' }}
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
      <button class="btn btn-secondary" @click="loadPolicies">Thử lại</button>
    </div>

    <!-- ─── Empty ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="policies.length === 0 && !showCreateForm" class="empty-state">
      <span class="empty-icon">🏌️</span>
      <p class="empty-title">Chưa có chính sách nào.</p>
      <p class="empty-subtitle">Tạo thể lệ đầu tiên để bắt đầu giới hạn tính năng ở chế độ giải đấu.</p>
      <button class="btn btn-primary" @click="showCreateForm = true">Tạo chính sách đầu tiên</button>
    </div>

    <!-- ─── Policy list ──────────────────────────────────────────────────────── -->
    <div v-else class="policy-list" role="list">
      <div
        v-for="policy in policies"
        :key="policy.id"
        class="policy-card"
        role="listitem"
        @click="navigateToPolicy(policy.id)"
      >
        <!-- Lock badge -->
        <div class="policy-header">
          <span class="policy-name">{{ policy.name }}</span>
          <span v-if="policy.isLocked" class="lock-badge" title="Chính sách đã khoá — không sửa được">
            🔒 Đã khoá
          </span>
        </div>

        <p v-if="policy.description" class="policy-description">{{ policy.description }}</p>

        <!-- Feature flags summary -->
        <div class="feature-summary">
          <span
            v-for="flag in enabledFlags(policy)"
            :key="flag"
            class="feature-pill pill-enabled"
          >{{ flagLabels[flag] }} ✓</span>
          <span
            v-for="flag in disabledFlags(policy)"
            :key="flag"
            class="feature-pill pill-disabled"
          >{{ flagLabels[flag] }} ✗</span>
        </div>

        <!-- Meta row -->
        <div class="policy-meta">
          <span class="meta-item">v{{ policy.version }}</span>
          <span class="meta-item">Tạo lúc {{ formatInstant(policy.createdAt) }}</span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import type {
  TournamentPolicyResponse,
  TournamentPolicyCreateRequest,
} from '@/types/tournament-policy';
import { tournamentPolicyApi } from '@/api/tournament-policy';
import { formatDay as formatInstant } from '@/lib/datetime';

const router = useRouter();

const policies = ref<TournamentPolicyResponse[]>([]);
const loading = ref(false);
const fetchError = ref<string | null>(null);

// ─── Create form state ────────────────────────────────────────────────────────
const showCreateForm = ref(false);
const creating = ref(false);
const createError = ref<string | null>(null);
const validationErrors = reactive<Record<string, string>>({});

const defaultFlags = () => ({
  windAdjustmentEnabled: true,
  playsLikeEnabled: true,
  elevationEnabled: true,
  clubRecommendationEnabled: true,
  contoursEnabled: true,
  puttingHelpEnabled: true,
  aiFeaturesEnabled: true,
});

const createForm = reactive<TournamentPolicyCreateRequest>({
  name: '',
  description: '',
  ...defaultFlags(),
});

const featureFlags: Array<{ key: keyof TournamentPolicyCreateRequest; label: string; description: string }> = [
  { key: 'windAdjustmentEnabled', label: 'Hiệu chỉnh gió', description: 'Cho phép hiệu chỉnh gió cho cú đánh' },
  { key: 'playsLikeEnabled', label: 'Cự ly quy đổi', description: 'Hiện cự ly quy đổi từ tee' },
  { key: 'elevationEnabled', label: 'Dữ liệu độ cao', description: 'Hiện thông tin độ cao' },
  { key: 'clubRecommendationEnabled', label: 'Gợi ý gậy', description: 'Hiện gợi ý gậy bằng AI' },
  { key: 'contoursEnabled', label: 'Đường đồng mức green', description: 'Hiện đường đồng mức green' },
  { key: 'puttingHelpEnabled', label: 'Hỗ trợ putt', description: 'Hiện lớp hỗ trợ putt' },
  { key: 'aiFeaturesEnabled', label: 'Tính năng AI', description: 'Bật Smart Target và các tính năng AI' },
];

const flagLabels: Record<string, string> = {
  windAdjustmentEnabled: 'Wind',
  playsLikeEnabled: 'Plays-Like',
  elevationEnabled: 'Elevation',
  clubRecommendationEnabled: 'Gợi ý gậy',
  contoursEnabled: 'Contours',
  puttingHelpEnabled: 'Hỗ trợ putt',
  aiFeaturesEnabled: 'AI',
};

function getFlagValue(key: string): boolean {
  return createForm[key as keyof TournamentPolicyCreateRequest] as boolean;
}

function setFlag(key: string, value: boolean) {
  (createForm as Record<string, unknown>)[key] = value;
}

function enabledFlags(policy: TournamentPolicyResponse): string[] {
  return Object.entries(policy)
    .filter(([k, v]) => typeof v === 'boolean' && v && k.endsWith('Enabled'))
    .map(([k]) => k);
}

function disabledFlags(policy: TournamentPolicyResponse): string[] {
  return Object.entries(policy)
    .filter(([k, v]) => typeof v === 'boolean' && !v && k.endsWith('Enabled'))
    .map(([k]) => k);
}

// ─── Load ─────────────────────────────────────────────────────────────────────

async function loadPolicies() {
  loading.value = true;
  fetchError.value = null;
  try {
    // This used to assign an empty array with a comment saying the API had no
    // list endpoint. It does now — and until it did, an operator who created a
    // policy came back to a page insisting none existed.
    policies.value = await tournamentPolicyApi.listPolicies(props.authToken);
  } catch (e: unknown) {
    const err = e as { message?: string };
    fetchError.value = err?.message ?? 'Không tải được danh sách chính sách';
  } finally {
    loading.value = false;
  }
}

async function handleCreate() {
  // Validate
  validationErrors.name = createForm.name.trim() ? '' : 'Policy name is required';
  if (validationErrors.name) return;

  creating.value = true;
  createError.value = null;
  try {
    const policy = await tournamentPolicyApi.createPolicy(createForm, props.authToken);
    // Reset form
    showCreateForm.value = false;
    Object.assign(createForm, { name: '', description: '', ...defaultFlags() });
    // Navigate to the new policy's detail page
    router.push(`/tournament-policies/${policy.id}`);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    createError.value = apiErr?.message ?? 'Không tạo được thể lệ';
  } finally {
    creating.value = false;
  }
}

function navigateToPolicy(id: string) {
  router.push(`/tournament-policies/${id}`);
}


const props = defineProps<{
  authToken: string;
}>();

onMounted(() => loadPolicies());
</script>

<style scoped>
.tournament-policies-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 800px;
  margin: 0 auto;
}

/* Header */
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

/* Buttons */
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

/* Create form */
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
.full-width { grid-column: 1 / -1; }
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
textarea.form-input { resize: vertical; }
.field-error {
  font-size: 0.75rem;
  color: #dc2626;
  margin-top: 0.125rem;
}

/* Feature toggles */
.feature-group {
  border: 1px solid var(--surface-container-highest);
  border-radius: 8px;
  padding: 1rem;
  margin-bottom: 1rem;
  background: var(--surface-container);
}
.feature-group-title {
  font-size: 0.875rem;
  font-weight: 600;
  color: #c5cde8;
  padding: 0 0.5rem;
}
.toggle-grid { display: flex; flex-direction: column; gap: 0.75rem; margin-top: 0.75rem; }
.toggle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}
.toggle-info { display: flex; flex-direction: column; gap: 0.1rem; }
.toggle-label { font-size: 0.875rem; font-weight: 500; color: var(--on-surface); }
.toggle-description { font-size: 0.75rem; color: var(--muted); }

.toggle-btn {
  position: relative;
  width: 44px;
  height: 24px;
  border-radius: 12px;
  border: none;
  cursor: pointer;
  transition: background 0.2s;
  flex-shrink: 0;
}
.toggle-off { background: var(--surface-container-highest); }
.toggle-on { background: var(--primary-container); }
.toggle-thumb {
  position: absolute;
  top: 2px;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--surface-container);
  transition: transform 0.2s;
  box-shadow: 0 1px 3px rgba(0,0,0,0.2);
}
.toggle-off .toggle-thumb { left: 2px; }
.toggle-on .toggle-thumb { transform: translateX(20px); }

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

/* Loading */
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

/* Error / Empty */
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

/* Policy list */
.policy-list { display: flex; flex-direction: column; gap: 0.75rem; }
.policy-card {
  border: 1px solid var(--surface-container-highest);
  border-radius: 10px;
  padding: 1rem;
  background: var(--surface-container);
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
.policy-card:hover {
  background: var(--surface-container);
  border-color: var(--primary-container);
}
.policy-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.35rem;
}
.policy-name {
  font-size: 1rem;
  font-weight: 600;
  color: var(--on-surface);
}
.lock-badge {
  font-size: 0.6875rem;
  font-weight: 600;
  padding: 0.15rem 0.5rem;
  border-radius: 9999px;
  background: #fef3c7;
  color: #92400e;
  border: 1px solid #f59e0b;
  white-space: nowrap;
}
.policy-description {
  font-size: 0.8125rem;
  color: var(--muted);
  margin: 0 0 0.5rem;
}
.feature-summary {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-bottom: 0.5rem;
}
.feature-pill {
  font-size: 0.6875rem;
  font-weight: 600;
  padding: 0.15rem 0.5rem;
  border-radius: 9999px;
  border: 1px solid currentColor;
}
.pill-enabled { color: #15803d; background: #dcfce7; }
.pill-disabled { color: var(--muted); background: var(--surface-container-high); }
.policy-meta {
  display: flex;
  gap: 1rem;
  font-size: 0.75rem;
  color: var(--muted);
}

@media (max-width: 640px) {
  .header-content { flex-basis: 100%; order: -1; }
  .tournament-policies-page { padding: 0; }
  .page-header > .btn, .page-header > a.btn, .page-header > button { flex: 1 1 auto; text-align: center; }
  .form-grid { grid-template-columns: 1fr; }
}
</style>
