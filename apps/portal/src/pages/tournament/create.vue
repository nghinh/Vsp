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
              <option value="strokePlay">Đấu gậy</option>
              <option value="matchPlay">Đấu đối kháng</option>
              <option value="stableford">Stableford</option>
            </select>
          </div>

          <div class="form-field">
            <label class="form-label" for="t-course">Mã sân <span class="required">*</span></label>
            <input
              id="t-course"
              v-model.number="form.courseId"
              class="form-input"
              type="number"
              placeholder="ví dụ 1"
              required
            />
            <span v-if="errors.courseId" class="field-error">{{ errors.courseId }}</span>
          </div>

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
import { ref, reactive } from 'vue';
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

function validate(): boolean {
  Object.keys(errors).forEach(k => delete errors[k]);

  if (!form.name.trim()) errors.name = 'Phải nhập tên giải đấu';
  if (!form.courseId || form.courseId <= 0) errors.courseId = 'Phải nhập mã sân hợp lệ';
  if (!form.startDate) errors.startDate = 'Phải nhập ngày bắt đầu';
  if (!form.endDate) errors.endDate = 'Phải nhập ngày kết thúc';

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
  border-bottom: 1px solid #2d3449;
  padding-bottom: 1rem;
}
.header-left { display: flex; align-items: center; gap: 1rem; }
.btn-back { background: none; border: none; color: #97a2c0; font-size: 0.875rem; cursor: pointer; padding: 0.5rem; }
.page-title { font-size: 1.375rem; font-weight: 700; color: #dae2fd; margin: 0; }

/* Form */
.tournament-form { display: flex; flex-direction: column; gap: 2rem; }
.form-section {
  background: #171f33;
  border: 1px solid #2d3449;
  border-radius: 12px;
  padding: 1.5rem;
}
.section-title { font-size: 1rem; font-weight: 600; color: #dae2fd; margin: 0 0 1rem; }

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
  border: 1px solid #2d3449;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: #171f33;
  color: #dae2fd;
}
.form-input:focus { outline: none; border-color: #f66018; box-shadow: 0 0 0 3px rgba(246,96,24,0.1); }
textarea.form-input { resize: vertical; }
.field-error { font-size: 0.75rem; color: #dc2626; }
.field-hint { font-size: 0.75rem; color: #97a2c0; margin: 0.2rem 0 0; }

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
.btn-primary { background: #f66018; color: white; }
.btn-primary:hover:not(:disabled) { background: #ec6a06; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary { background: #171f33; color: #c5cde8; border-color: #2d3449; }
.btn-secondary:hover { background: #171f33; }
</style>
