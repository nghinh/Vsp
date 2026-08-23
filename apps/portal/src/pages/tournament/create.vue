<template>
  <div class="create-tournament-page">

    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="$router.push('/tournaments')">← Huỷ</button>
        <h1 class="page-title">Tạo giải đấu</h1>
      </div>
    </header>

    <form class="tournament-form" @submit.prevent="handleSubmit" novalidate>

      <!-- ─── Basic Info ──────────────────────────────────────────────── -->
      <section class="form-section">
        <h2 class="section-title">Thông tin cơ bản</h2>

        <div class="form-grid">
          <div class="form-field full-width">
            <label class="form-label" for="t-name">
              Tên giải <span class="required">*</span>
            </label>
            <input
              id="t-name"
              v-model="form.name"
              class="form-input"
              type="text"
              placeholder="ví dụ Giải vô địch CLB 2026"
              autocomplete="off"
              required
            />
            <span v-if="errors.name" class="field-error">{{ errors.name }}</span>
          </div>

          <div class="form-field">
            <label class="form-label" for="t-format">Thể thức <span class="required">*</span></label>
            <select id="t-format" v-model="form.format" class="form-input" required>
              <option v-for="(text, value) in TOURNAMENT_FORMAT_LABELS" :key="value" :value="value">
                {{ text }}
              </option>
            </select>
          </div>
        </div>

        <!--
          A number box labelled "Mã sân" used to sit here, defaulting to 0. A
          tournament director does not know that Sky Lake Championship is
          course 2, and the form gave them nothing to look it up with.
        -->
        <CoursePicker v-model="courseId" :auth-token="authToken" />
        <span v-if="errors.courseId" class="field-error">{{ errors.courseId }}</span>

        <div class="form-grid">

          <div class="form-field">
            <label class="form-label" for="t-max">Số golfer tối đa</label>
            <input
              id="t-max"
              v-model.number="form.maxPlayers"
              class="form-input"
              type="number"
              min="2"
              max="200"
              placeholder="ví dụ 40"
            />
          </div>

          <div class="form-field">
            <label class="form-label" for="t-reg-deadline">Hạn đăng ký</label>
            <input
              id="t-reg-deadline"
              v-model="form.registrationDeadline"
              class="form-input"
              type="datetime-local"
            />
          </div>

          <div class="form-field full-width">
            <label class="form-label" for="t-desc">Mô tả</label>
            <textarea
              id="t-desc"
              v-model="form.description"
              class="form-input"
              rows="3"
              placeholder="Mô tả (không bắt buộc)…"
            />
          </div>
        </div>
      </section>

      <!-- ─── Dates ─────────────────────────────────────────────────── -->
      <section class="form-section">
        <h2 class="section-title">Thời gian giải</h2>
        <div class="form-grid">
          <div class="form-field">
            <label class="form-label" for="t-start">Ngày bắt đầu <span class="required">*</span></label>
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
            <label class="form-label" for="t-end">Ngày kết thúc <span class="required">*</span></label>
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
        <h2 class="section-title">Chính sách giải</h2>
        <div class="form-field">
          <label class="form-label" for="t-policy">Chính sách</label>
          <select id="t-policy" v-model="form.tournamentPolicyId" class="form-input">
            <option value="">— Không giới hạn (bật toàn bộ tính năng) —</option>
            <option v-for="p in policies" :key="p.id" :value="p.id">
              {{ p.name }} (v{{ p.version }})
            </option>
          </select>
          <p class="field-hint">Chọn chính sách để hạn chế tính năng trong lúc thi đấu.</p>
        </div>
      </section>

      <!-- ─── Error ─────────────────────────────────────────────────── -->
      <div v-if="submitError" class="error-banner" role="alert">
        {{ submitError }}
      </div>

      <!-- ─── Submit ────────────────────────────────────────────────── -->
      <div class="form-actions">
        <button type="button" class="btn btn-secondary" @click="$router.push('/tournaments')">
          Huỷ
        </button>
        <button type="submit" class="btn btn-primary" :disabled="submitting">
          {{ submitting ? 'Đang tạo…' : 'Tạo giải đấu' }}
        </button>
      </div>

    </form>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import CoursePicker from '@/components/CoursePicker.vue';
import { tournamentApi } from '@/api/tournament';
import { TOURNAMENT_FORMAT_LABELS } from '@/lib/enum-labels';
import type { TournamentCreateRequest } from '@/types/tournament';
import type { TournamentPolicyResponse } from '@/types/tournament-policy';

const router = useRouter();
const props = defineProps<{ authToken: string }>();

/** Held apart from `form` because the picker's "nothing chosen" is null. */
const courseId = ref<number | null>(null);

const form = reactive<Omit<TournamentCreateRequest, 'courseId'> & { registrationDeadline?: string }>({
  name: '',
  format: 'STROKE_PLAY',
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
// No policies are loaded, because there is nothing to load them from.
//
// /tournament-policies serves POST, GET /{id}, PATCH /{id}, POST /{id}/lock
// and GET /{id}/changes — there is no list endpoint, so this dropdown cannot
// be populated. It used to hold an empty try/catch with a comment saying a
// real app would have one, which rendered a select containing only the
// "no restrictions" option and no way to tell whether that was the truth or a
// failed request.
//
// The picker now says so. Restore the list when the endpoint exists.
const policies = ref<TournamentPolicyResponse[]>([]);

/** Field ids in the order they appear, so "the first error" means the top one. */
const FIELD_ORDER: Record<string, string> = {
  name: 't-name',
  courseId: 'cp-facility',
  startDate: 't-start',
  endDate: 't-end',
};

function validate(): boolean {
  Object.keys(errors).forEach(k => delete errors[k]);

  if (!form.name.trim()) errors.name = 'Phải nhập tên giải đấu';
  if (!courseId.value || courseId.value <= 0) errors.courseId = 'Phải chọn sân thi đấu';
  if (!form.startDate) errors.startDate = 'Phải nhập ngày bắt đầu';
  if (!form.endDate) errors.endDate = 'Phải nhập ngày kết thúc';

  return Object.keys(errors).length === 0;
}

/**
 * Take the operator to the first thing that is wrong.
 *
 * The submit button is at the bottom of a form two screens tall and every
 * error message sits beside its field, so pressing it with the top of the form
 * empty looked exactly like pressing a dead button: nothing moved, nothing
 * appeared, no request went out.
 */
async function focusFirstError() {
  await nextTick();
  const first = Object.keys(FIELD_ORDER).find((key) => errors[key]);
  if (!first) return;
  const el = document.getElementById(FIELD_ORDER[first]);
  el?.scrollIntoView({ block: 'center', behavior: 'smooth' });
  (el as HTMLElement | null)?.focus?.();
}

async function handleSubmit() {
  if (!validate()) {
    await focusFirstError();
    return;
  }

  submitting.value = true;
  submitError.value = null;

  try {
    const request: TournamentCreateRequest = {
      name: form.name.trim(),
      format: form.format,
      courseId: courseId.value as number,
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
    submitError.value = apiErr?.message ?? 'Không tạo được giải đấu';
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
  border-bottom: 1px solid var(--surface-container-highest);
  padding-bottom: 1rem;
}
.header-left { display: flex; align-items: center; gap: 1rem; }
.btn-back { background: none; border: none; color: var(--muted); font-size: 0.875rem; cursor: pointer; padding: 0.5rem; }
.page-title { font-size: 1.375rem; font-weight: 700; color: var(--on-surface); margin: 0; }

/* Form */
.tournament-form { display: flex; flex-direction: column; gap: 2rem; }
.form-section {
  background: var(--surface-container);
  border: 1px solid var(--surface-container-highest);
  border-radius: 12px;
  padding: 1.5rem;
}
.section-title { font-size: 1rem; font-weight: 600; color: var(--on-surface); margin: 0 0 1rem; }

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}
.full-width { grid-column: 1 / -1; }

.form-field { display: flex; flex-direction: column; gap: 0.3rem; }
.form-label { font-size: 0.8125rem; font-weight: 600; color: #c5cde8; }
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
.form-input:focus { outline: none; border-color: var(--primary-container); box-shadow: 0 0 0 3px rgba(246,96,24,0.1); }
textarea.form-input { resize: vertical; }
.field-error { font-size: 0.75rem; color: #dc2626; }
.field-hint { font-size: 0.75rem; color: var(--muted); margin: 0.2rem 0 0; }

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
.btn-primary { background: var(--primary-container); color: white; }
.btn-primary:hover:not(:disabled) { background: var(--secondary-container); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary { background: var(--surface-container); color: #c5cde8; border-color: var(--surface-container-highest); }
.btn-secondary:hover { background: var(--surface-container); }

@media (max-width: 640px) {
  .create-tournament-page { padding: 0; }
  .page-header > .btn, .page-header > a.btn, .page-header > button { flex: 1 1 auto; text-align: center; }
  .form-grid { grid-template-columns: 1fr; }
}
</style>
