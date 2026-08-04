<template>
  <div class="create-tournament-page">

    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="$router.push('/tournament')">← Cancel</button>
        <h1 class="page-title">Create Tournament</h1>
      </div>
    </header>

    <form class="tournament-form" @submit.prevent="handleSubmit" novalidate>

      <!-- ─── Basic Info ──────────────────────────────────────────────── -->
      <section class="form-section">
        <h2 class="section-title">Basic Information</h2>

        <div class="form-grid">
          <div class="form-field full-width">
            <label class="form-label" for="t-name">
              Tournament Name <span class="required">*</span>
            </label>
            <input
              id="t-name"
              v-model="form.name"
              class="form-input"
              type="text"
              placeholder="e.g. Club Championship 2026"
              autocomplete="off"
              required
            />
            <span v-if="errors.name" class="field-error">{{ errors.name }}</span>
          </div>

          <div class="form-field">
            <label class="form-label" for="t-format">Format <span class="required">*</span></label>
            <select id="t-format" v-model="form.format" class="form-input" required>
              <option value="strokePlay">Stroke Play</option>
              <option value="matchPlay">Match Play</option>
              <option value="stableford">Stableford</option>
            </select>
          </div>

          <div class="form-field">
            <label class="form-label" for="t-course">Course ID <span class="required">*</span></label>
            <input
              id="t-course"
              v-model.number="form.courseId"
              class="form-input"
              type="number"
              placeholder="e.g. 1"
              required
            />
            <span v-if="errors.courseId" class="field-error">{{ errors.courseId }}</span>
          </div>

          <div class="form-field">
            <label class="form-label" for="t-max">Max Players</label>
            <input
              id="t-max"
              v-model.number="form.maxPlayers"
              class="form-input"
              type="number"
              min="2"
              max="200"
              placeholder="e.g. 40"
            />
          </div>

          <div class="form-field">
            <label class="form-label" for="t-reg-deadline">Registration Deadline</label>
            <input
              id="t-reg-deadline"
              v-model="form.registrationDeadline"
              class="form-input"
              type="datetime-local"
            />
          </div>

          <div class="form-field full-width">
            <label class="form-label" for="t-desc">Description</label>
            <textarea
              id="t-desc"
              v-model="form.description"
              class="form-input"
              rows="3"
              placeholder="Optional description..."
            />
          </div>
        </div>
      </section>

      <!-- ─── Dates ─────────────────────────────────────────────────── -->
      <section class="form-section">
        <h2 class="section-title">Tournament Dates</h2>
        <div class="form-grid">
          <div class="form-field">
            <label class="form-label" for="t-start">Start Date <span class="required">*</span></label>
            <input
              id="t-start"
              v-model="form.startDate"
              class="form-input"
              type="datetime-local"
              required
            />
            <span v-if="errors.startDate" class="field-error">{{ errors.startDate }}</span>
          </div>
          <div class="form-field">
            <label class="form-label" for="t-end">End Date <span class="required">*</span></label>
            <input
              id="t-end"
              v-model="form.endDate"
              class="form-input"
              type="datetime-local"
              required
            />
            <span v-if="errors.endDate" class="field-error">{{ errors.endDate }}</span>
          </div>
        </div>
      </section>

      <!-- ─── Policy ────────────────────────────────────────────────── -->
      <section class="form-section">
        <h2 class="section-title">Tournament Policy</h2>
        <div class="form-field">
          <label class="form-label" for="t-policy">Policy</label>
          <select id="t-policy" v-model="form.tournamentPolicyId" class="form-input">
            <option value="">— No restrictions (all features enabled) —</option>
            <option v-for="p in policies" :key="p.id" :value="p.id">
              {{ p.name }} (v{{ p.version }})
            </option>
          </select>
          <p class="field-hint">Select a policy to restrict features during tournament play.</p>
        </div>
      </section>

      <!-- ─── Error ─────────────────────────────────────────────────── -->
      <div v-if="submitError" class="error-banner" role="alert">
        {{ submitError }}
      </div>

      <!-- ─── Submit ────────────────────────────────────────────────── -->
      <div class="form-actions">
        <button type="button" class="btn btn-secondary" @click="$router.push('/tournament')">
          Cancel
        </button>
        <button type="submit" class="btn btn-primary" :disabled="submitting">
          {{ submitting ? 'Creating…' : 'Create Tournament' }}
        </button>
      </div>

    </form>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { tournamentApi } from '@/api/tournament';
import type { TournamentCreateRequest } from '@/types/tournament';
import type { TournamentPolicyResponse } from '@/types/tournament-policy';

const router = useRouter();
const props = defineProps<{ authToken: string }>();

const form = reactive<TournamentCreateRequest & { registrationDeadline?: string }>({
  name: '',
  format: 'strokePlay',
  courseId: 0,
  startDate: '',
  endDate: '',
  tournamentPolicyId: '',
  maxPlayers: undefined,
  description: '',
  registrationDeadline: undefined,
});

const errors = reactive<Record<string, string>>({});
const submitting = ref(false);
const submitError = ref<string | null>(null);
const policies = ref<TournamentPolicyResponse[]>([]);

onMounted(async () => {
  try {
    // Load policies for selection — use the existing policy API
    // In a real app, there would be a list endpoint
  } catch (_) {}
});

function validate(): boolean {
  Object.keys(errors).forEach(k => delete errors[k]);

  if (!form.name.trim()) errors.name = 'Tournament name is required';
  if (!form.courseId || form.courseId <= 0) errors.courseId = 'Valid course ID is required';
  if (!form.startDate) errors.startDate = 'Start date is required';
  if (!form.endDate) errors.endDate = 'End date is required';

  return Object.keys(errors).length === 0;
}

async function handleSubmit() {
  if (!validate()) return;

  submitting.value = true;
  submitError.value = null;

  try {
    const request: TournamentCreateRequest = {
      name: form.name.trim(),
      format: form.format,
      courseId: form.courseId,
      startDate: new Date(form.startDate).toISOString(),
      endDate: new Date(form.endDate).toISOString(),
      tournamentPolicyId: form.tournamentPolicyId || undefined,
      maxPlayers: form.maxPlayers,
      description: form.description || undefined,
      registrationDeadline: form.registrationDeadline
          ? new Date(form.registrationDeadline).toISOString()
          : undefined,
    };

    const created = await tournamentApi.createTournament(props.authToken, request);
    router.push(`/tournament/${created.id}`);
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    submitError.value = apiErr?.message ?? 'Failed to create tournament';
  } finally {
    submitting.value = false;
  }
}
</script>

<style scoped>
.create-tournament-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 700px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 2rem;
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 1rem;
}
.header-left { display: flex; align-items: center; gap: 1rem; }
.btn-back { background: none; border: none; color: #6b7280; font-size: 0.875rem; cursor: pointer; padding: 0.5rem; }
.page-title { font-size: 1.375rem; font-weight: 700; color: #111827; margin: 0; }

/* Form */
.tournament-form { display: flex; flex-direction: column; gap: 2rem; }
.form-section {
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  padding: 1.5rem;
}
.section-title { font-size: 1rem; font-weight: 600; color: #111827; margin: 0 0 1rem; }

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}
.full-width { grid-column: 1 / -1; }

.form-field { display: flex; flex-direction: column; gap: 0.3rem; }
.form-label { font-size: 0.8125rem; font-weight: 600; color: #374151; }
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
.form-input:focus { outline: none; border-color: #2563eb; box-shadow: 0 0 0 3px rgba(37,99,235,0.1); }
textarea.form-input { resize: vertical; }
.field-error { font-size: 0.75rem; color: #dc2626; }
.field-hint { font-size: 0.75rem; color: #6b7280; margin: 0.2rem 0 0; }

.error-banner {
  background: #fee2e2;
  color: #991b1b;
  border: 1px solid #fecaca;
  border-radius: 8px;
  padding: 0.75rem 1rem;
  font-size: 0.875rem;
}

.form-actions { display: flex; gap: 0.75rem; justify-content: flex-end; }

.btn {
  padding: 0.6rem 1.25rem;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid transparent;
  min-height: 44px;
  transition: background 0.15s;
}
.btn-primary { background: #2563eb; color: white; }
.btn-primary:hover:not(:disabled) { background: #1d4ed8; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary { background: white; color: #374151; border-color: #d1d5db; }
.btn-secondary:hover { background: #f9fafb; }
</style>
