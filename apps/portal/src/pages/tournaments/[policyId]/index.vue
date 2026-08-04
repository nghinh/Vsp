<template>
  <div class="policy-detail-page">

    <!-- ─── Header ──────────────────────────────────────────────────────────── -->
    <header class="page-header">
      <div class="header-left">
        <button class="back-btn" @click="router.push('/tournaments')" aria-label="Back to policies">
          ← Back
        </button>
        <div>
          <h1 class="page-title">{{ policy ? policy.name : 'Loading…' }}</h1>
          <div v-if="policy" class="header-badges">
            <span v-if="policy.isLocked" class="lock-badge">
              🔒 Locked — requires Tournament Director to edit
            </span>
            <span v-else class="unlocked-badge">🔓 Unlocked</span>
          </div>
        </div>
      </div>
      <div class="header-actions">
        <button
          v-if="policy && !policy.isLocked"
          class="btn btn-danger"
          :disabled="locking"
          @click="handleLock"
        >
          {{ locking ? 'Locking…' : '🔒 Lock Policy' }}
        </button>
      </div>
    </header>

    <!-- ─── Loading ─────────────────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true">
      <div class="skeleton-form" />
    </div>

    <!-- ─── Error ───────────────────────────────────────────────────────────── -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="btn btn-secondary" @click="loadPolicy">Retry</button>
    </div>

    <!-- ─── Policy editor ───────────────────────────────────────────────────── -->
    <template v-else-if="policy">

      <!-- Locked notice -->
      <div v-if="policy.isLocked" class="locked-notice" role="alert">
        <span>🔒 This policy is locked. Feature flags cannot be changed until it is unlocked by a Tournament Director.</span>
      </div>

      <!-- Save error -->
      <div v-if="saveError" class="save-error" role="alert">
        <span>⚠ {{ saveError }}</span>
        <button @click="saveError = null">Dismiss</button>
      </div>

      <!-- Policy metadata -->
      <div class="meta-row">
        <span class="meta-item">v{{ policy.version }}</span>
        <span class="meta-sep">·</span>
        <span class="meta-item">Created {{ formatInstant(policy.createdAt) }}</span>
        <span class="meta-sep">·</span>
        <span class="meta-item">Created by account #{{ policy.createdBy }}</span>
      </div>

      <!-- Name / description -->
      <div class="form-section">
        <div class="form-field">
          <label class="form-label" for="policy-name">Policy Name</label>
          <input
            id="policy-name"
            v-model="editForm.name"
            class="form-input"
            type="text"
            :disabled="policy.isLocked"
          />
        </div>
        <div class="form-field">
          <label class="form-label" for="policy-desc">Description</label>
          <textarea
            id="policy-desc"
            v-model="editForm.description"
            class="form-input"
            rows="2"
            :disabled="policy.isLocked"
          />
        </div>
      </div>

      <!-- Feature flags editor -->
      <fieldset class="feature-group" :disabled="policy.isLocked">
        <legend class="feature-group-title">Feature Flags</legend>

        <div class="toggle-grid">
          <div v-for="flag in featureFlags" :key="flag.key" class="toggle-row">
            <div class="toggle-info">
              <span class="toggle-label">{{ flag.label }}</span>
              <span class="toggle-description">{{ flag.description }}</span>
            </div>
            <button
              class="toggle-btn"
              :class="getFlagValue(flag.key) ? 'toggle-on' : 'toggle-off'"
              :disabled="policy.isLocked"
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

      <!-- Save button -->
      <div v-if="!policy.isLocked" class="form-actions">
        <button
          class="btn btn-primary"
          :disabled="saving || !hasChanges"
          @click="handleSave"
        >
          {{ saving ? 'Saving…' : 'Save Changes' }}
        </button>
        <span class="change-count" v-if="changeCount > 0">
          {{ changeCount }} change{{ changeCount !== 1 ? 's' : '' }} pending
        </span>
      </div>

      <!-- ─── Audit timeline ─────────────────────────────────────────────────── -->
      <div class="audit-section">
        <h2 class="audit-title">Change History</h2>

        <div v-if="auditLoading" class="audit-loading">Loading history…</div>
        <div v-else-if="auditError" class="audit-error">Failed to load history: {{ auditError }}</div>
        <div v-else-if="auditLog.length === 0" class="audit-empty">
          No changes recorded yet.
        </div>
        <div v-else class="audit-timeline" role="list">
          <div
            v-for="entry in auditLog"
            :key="entry.id"
            class="audit-entry"
            role="listitem"
          >
            <div class="audit-entry-header">
              <span class="audit-actor">Account #{{ entry.changedBy }}</span>
              <span class="audit-time">{{ formatInstant(entry.changedAt) }}</span>
            </div>
            <div v-if="entry.reason" class="audit-reason">Reason: {{ entry.reason }}</div>

            <!-- Before / After diff -->
            <div class="audit-diff">
              <div class="diff-col diff-before">
                <span class="diff-label">Before</span>
                <div v-if="entry.beforeJson" class="diff-flags">
                  <span
                    v-for="flag in parseFlags(entry.beforeJson)"
                    :key="flag.key"
                    class="flag-chip"
                    :class="flag.value ? 'chip-on' : 'chip-off'"
                  >{{ flag.label }}: {{ flag.value ? 'ON' : 'OFF' }}</span>
                </div>
                <span v-else class="diff-none">(created)</span>
              </div>
              <div class="diff-arrow">→</div>
              <div class="diff-col diff-after">
                <span class="diff-label">After</span>
                <div v-if="entry.afterJson" class="diff-flags">
                  <span
                    v-for="flag in parseFlags(entry.afterJson)"
                    :key="flag.key"
                    class="flag-chip"
                    :class="flag.value ? 'chip-on' : 'chip-off'"
                  >{{ flag.label }}: {{ flag.value ? 'ON' : 'OFF' }}</span>
                </div>
                <span v-else class="diff-none">(removed)</span>
              </div>
            </div>
          </div>
        </div>
      </div>

    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import type {
  TournamentPolicyResponse,
  TournamentPolicyUpdateRequest,
  TournamentPolicyChangeDto,
} from '@/types/tournament-policy';
import { tournamentPolicyApi } from '@/api/tournament-policy';

const props = defineProps<{
  policyId: string;
  authToken: string;
}>();

const router = useRouter();

const policy = ref<TournamentPolicyResponse | null>(null);
const loading = ref(false);
const fetchError = ref<string | null>(null);
const saving = ref(false);
const saveError = ref<string | null>(null);
const locking = ref(false);

// Audit log
const auditLog = ref<TournamentPolicyChangeDto[]>([]);
const auditLoading = ref(false);
const auditError = ref<string | null>(null);

// Editable form (mirrors current policy)
const editForm = reactive<TournamentPolicyUpdateRequest>({
  name: '',
  description: null,
  windAdjustmentEnabled: true,
  playsLikeEnabled: true,
  elevationEnabled: true,
  clubRecommendationEnabled: true,
  contoursEnabled: true,
  puttingHelpEnabled: true,
  aiFeaturesEnabled: true,
});

const featureFlags: Array<{ key: keyof TournamentPolicyUpdateRequest; label: string; description: string }> = [
  { key: 'windAdjustmentEnabled', label: 'Wind Adjustment', description: 'Allow wind adjustment on shots' },
  { key: 'playsLikeEnabled', label: 'Plays-Like Distances', description: 'Show plays-like distances from tee' },
  { key: 'elevationEnabled', label: 'Elevation Data', description: 'Display elevation information' },
  { key: 'clubRecommendationEnabled', label: 'Club Recommendation', description: 'Show AI club suggestions' },
  { key: 'contoursEnabled', label: 'Green Contours', description: 'Display putting green contours' },
  { key: 'puttingHelpEnabled', label: 'Putting Help', description: 'Show putting assistance overlays' },
  { key: 'aiFeaturesEnabled', label: 'AI Features', description: 'Enable Smart Target and AI features' },
];

const flagLabels: Record<string, string> = {
  windAdjustmentEnabled: 'Wind',
  playsLikeEnabled: 'Plays-Like',
  elevationEnabled: 'Elevation',
  clubRecommendationEnabled: 'Club Rec',
  contoursEnabled: 'Contours',
  puttingHelpEnabled: 'Putting Help',
  aiFeaturesEnabled: 'AI',
};

function getFlagValue(key: string): boolean {
  return (editForm as Record<string, unknown>)[key] as boolean;
}

function setFlag(key: string, value: boolean) {
  (editForm as Record<string, unknown>)[key] = value;
}

function populateEditForm(p: TournamentPolicyResponse) {
  editForm.name = p.name;
  editForm.description = p.description ?? null;
  editForm.windAdjustmentEnabled = p.windAdjustmentEnabled;
  editForm.playsLikeEnabled = p.playsLikeEnabled;
  editForm.elevationEnabled = p.elevationEnabled;
  editForm.clubRecommendationEnabled = p.clubRecommendationEnabled;
  editForm.contoursEnabled = p.contoursEnabled;
  editForm.puttingHelpEnabled = p.puttingHelpEnabled;
  editForm.aiFeaturesEnabled = p.aiFeaturesEnabled;
}

const changeCount = computed(() => {
  if (!policy.value) return 0;
  let count = 0;
  if (editForm.name !== policy.value.name) count++;
  if (editForm.description !== policy.value.description) count++;
  const flags = featureFlags.map(f => f.key);
  for (const key of flags) {
    if ((editForm as Record<string, unknown>)[key] !== (policy.value as Record<string, unknown>)[key]) {
      count++;
    }
  }
  return count;
});

const hasChanges = computed(() => changeCount.value > 0);

// ─── Load ─────────────────────────────────────────────────────────────────────

async function loadPolicy() {
  loading.value = true;
  fetchError.value = null;
  try {
    policy.value = await tournamentPolicyApi.getPolicy(props.policyId, props.authToken);
    if (policy.value) populateEditForm(policy.value);
  } catch (err: unknown) {
    fetchError.value = (err as { message?: string })?.message ?? 'Failed to load policy';
  } finally {
    loading.value = false;
  }
}

async function loadAuditLog() {
  auditLoading.value = true;
  auditError.value = null;
  try {
    auditLog.value = await tournamentPolicyApi.getPolicyChanges(props.policyId, props.authToken);
  } catch (err: unknown) {
    auditError.value = (err as { message?: string })?.message ?? 'Failed to load audit log';
  } finally {
    auditLoading.value = false;
  }
}

async function handleSave() {
  saving.value = true;
  saveError.value = null;
  try {
    const updated = await tournamentPolicyApi.updatePolicy(props.policyId, editForm, props.authToken);
    policy.value = updated;
    populateEditForm(updated);
    await loadAuditLog(); // refresh timeline
  } catch (err: unknown) {
    saveError.value = (err as { message?: string })?.message ?? 'Failed to save changes';
  } finally {
    saving.value = false;
  }
}

async function handleLock() {
  locking.value = true;
  try {
    const updated = await tournamentPolicyApi.lockPolicy(props.policyId, props.authToken);
    policy.value = updated;
    populateEditForm(updated);
    await loadAuditLog();
  } finally {
    locking.value = false;
  }
}

// ─── Audit diff helpers ────────────────────────────────────────────────────────

interface FlagEntry { key: string; label: string; value: boolean }

function parseFlags(json: string): FlagEntry[] {
  try {
    const obj = JSON.parse(json) as Record<string, unknown>;
    return featureFlags
      .filter(f => typeof obj[f.key] === 'boolean')
      .map(f => ({ key: f.key, label: flagLabels[f.key], value: obj[f.key] as boolean }));
  } catch {
    return [];
  }
}

function formatInstant(iso: string): string {
  return new Date(iso).toLocaleString();
}

onMounted(() => {
  loadPolicy();
  loadAuditLog();
});
</script>

<style scoped>
.policy-detail-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 700px;
  margin: 0 auto;
}

/* Header */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.25rem;
  border-bottom: 1px solid #2d3449;
  padding-bottom: 1rem;
}
.header-left { display: flex; align-items: flex-start; gap: 0.75rem; }
.back-btn {
  background: none;
  border: none;
  color: #f66018;
  cursor: pointer;
  font-size: 0.875rem;
  min-height: 44px;
  padding: 0.5rem 0;
}
.page-title { font-size: 1.25rem; font-weight: 700; color: #dae2fd; margin: 0; }
.header-badges { display: flex; gap: 0.5rem; margin-top: 0.25rem; }
.lock-badge {
  font-size: 0.75rem;
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
  background: #fef3c7;
  color: #92400e;
  border: 1px solid #f59e0b;
  font-weight: 600;
}
.unlocked-badge {
  font-size: 0.75rem;
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
  background: #dcfce7;
  color: #15803d;
  border: 1px solid #22c55e;
  font-weight: 600;
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
}
.btn-primary { background: #f66018; color: white; }
.btn-primary:hover:not(:disabled) { background: #ec6a06; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary { background: #171f33; color: #c5cde8; border-color: #2d3449; }
.btn-danger { background: #dc2626; color: white; }
.btn-danger:hover:not(:disabled) { background: #b91c1c; }
.btn-danger:disabled { opacity: 0.5; cursor: not-allowed; }

/* Locked notice */
.locked-notice {
  background: #fef3c7;
  border: 1px solid #f59e0b;
  border-radius: 8px;
  padding: 0.75rem 1rem;
  margin-bottom: 1rem;
  font-size: 0.875rem;
  color: #92400e;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.save-error {
  background: #fee2e2;
  border: 1px solid #dc2626;
  border-radius: 8px;
  padding: 0.75rem 1rem;
  margin-bottom: 1rem;
  font-size: 0.875rem;
  color: #b91c1c;
  display: flex;
  align-items: center;
  gap: 0.75rem;
}
.save-error button {
  margin-left: auto;
  background: none;
  border: none;
  color: #b91c1c;
  cursor: pointer;
  font-size: 0.875rem;
  text-decoration: underline;
}

/* Meta */
.meta-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
  color: #97a2c0;
  margin-bottom: 1rem;
}
.meta-sep { color: #2d3449; }

/* Form */
.form-section {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}
.form-field { display: flex; flex-direction: column; gap: 0.25rem; }
.form-label { font-size: 0.8125rem; font-weight: 600; color: #c5cde8; }
.form-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #2d3449;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: #171f33;
  color: #dae2fd;
}
.form-input:focus { outline: none; border-color: #f66018; box-shadow: 0 0 0 3px rgba(246,96,24,0.1); }
.form-input:disabled { background: #222a3d; color: #97a2c0; cursor: not-allowed; }
textarea.form-input { resize: vertical; }

/* Feature toggles */
.feature-group {
  border: 1px solid #2d3449;
  border-radius: 8px;
  padding: 1rem;
  margin-bottom: 1.25rem;
  background: #171f33;
}
.feature-group:disabled { opacity: 0.7; background: #171f33; cursor: not-allowed; }
.feature-group-title { font-size: 0.875rem; font-weight: 600; color: #c5cde8; padding: 0 0.5rem; }
.toggle-grid { display: flex; flex-direction: column; gap: 0.75rem; margin-top: 0.75rem; }
.toggle-row { display: flex; align-items: center; justify-content: space-between; gap: 1rem; }
.toggle-info { display: flex; flex-direction: column; gap: 0.1rem; }
.toggle-label { font-size: 0.875rem; font-weight: 500; color: #dae2fd; }
.toggle-description { font-size: 0.75rem; color: #97a2c0; }

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
.toggle-btn:disabled { cursor: not-allowed; }
.toggle-off { background: #2d3449; }
.toggle-on { background: #f66018; }
.toggle-thumb {
  position: absolute;
  top: 2px;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: #171f33;
  transition: transform 0.2s;
  box-shadow: 0 1px 3px rgba(0,0,0,0.2);
}
.toggle-off .toggle-thumb { left: 2px; }
.toggle-on .toggle-thumb { transform: translateX(20px); }

.form-actions {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 2rem;
}
.change-count { font-size: 0.8125rem; color: #97a2c0; }

/* Loading / error / empty */
.loading-state { display: flex; flex-direction: column; gap: 0.75rem; }
.skeleton-form {
  height: 20rem;
  border-radius: 8px;
  background: linear-gradient(90deg, #2d3449 25%, #222a3d 50%, #2d3449 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
.error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 1rem;
  color: #dc2626;
  text-align: center;
  font-size: 0.875rem;
}
.error-icon { font-size: 2rem; }

/* Audit timeline */
.audit-section {
  border-top: 1px solid #2d3449;
  padding-top: 1.5rem;
}
.audit-title { font-size: 1rem; font-weight: 600; color: #dae2fd; margin: 0 0 1rem; }
.audit-loading,
.audit-error,
.audit-empty {
  font-size: 0.875rem;
  color: #97a2c0;
  padding: 1rem 0;
}
.audit-error { color: #dc2626; }
.audit-timeline { display: flex; flex-direction: column; gap: 1rem; }
.audit-entry {
  border: 1px solid #2d3449;
  border-radius: 8px;
  padding: 0.75rem 1rem;
  background: #171f33;
}
.audit-entry-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.25rem;
}
.audit-actor { font-size: 0.8125rem; font-weight: 600; color: #c5cde8; }
.audit-time { font-size: 0.75rem; color: #97a2c0; }
.audit-reason { font-size: 0.75rem; color: #97a2c0; margin-bottom: 0.5rem; font-style: italic; }
.audit-diff { display: grid; grid-template-columns: 1fr auto 1fr; gap: 0.75rem; align-items: start; }
.diff-col { display: flex; flex-direction: column; gap: 0.25rem; }
.diff-label { font-size: 0.6875rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: #97a2c0; }
.diff-flags { display: flex; flex-wrap: wrap; gap: 0.25rem; }
.diff-none { font-size: 0.75rem; color: #97a2c0; font-style: italic; }
.diff-arrow { font-size: 1rem; color: #2d3449; padding-top: 1rem; }
.flag-chip {
  font-size: 0.6875rem;
  font-weight: 600;
  padding: 0.1rem 0.4rem;
  border-radius: 4px;
  border: 1px solid currentColor;
}
.chip-on { color: #15803d; background: #dcfce7; }
.chip-off { color: #97a2c0; background: #222a3d; }
</style>
