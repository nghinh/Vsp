<script setup lang="ts">
/**
 * Course conditions — what the course is like today, and per-green readings.
 *
 * Two different things share this page because they answer one question and a
 * greenkeeper records them in one visit:
 *
 *   course conditions   whole-course facts with a severity: cart path only,
 *                       temporary greens, maintenance, weather
 *   green conditions    per-hole measurements: stimpmeter, firmness, moisture
 *
 * Both endpoints existed and neither had a caller. The placeholder that stood
 * here listed `/courses/{id}/green-conditions` without the `/admin` prefix and
 * without the `/holes/{n}` segment the write endpoints require.
 *
 * Everything published here carries an effective window. A green speed from
 * three weeks ago is not a green speed; it is a number that will be quoted to
 * a golfer lining up a putt.
 */
import { computed, ref } from 'vue';

import { operationsApi } from '@/api/admin/operations';
import CoursePicker from '@/components/CoursePicker.vue';
import type { CourseResponse } from '@/types/admin/course';
import type { CourseCondition, GreenCondition } from '@/types/admin/operations';
import { hoursFromNowLocalInput, nowLocalInput, toLocalInput } from '@/lib/datetime';
import {
  CONDITION_TYPES,
  FIRMNESS,
  MOISTURE,
  SEVERITIES,
  STIMPMETER_MAX,
  STIMPMETER_MIN,
} from '@/types/admin/operations';

const props = defineProps<{ authToken: string }>();

const courseId = ref<number | null>(null);
const course = ref<CourseResponse | null>(null);
const conditions = ref<CourseCondition[]>([]);
const greens = ref<GreenCondition[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);
const notice = ref<string | null>(null);

const tab = ref<'course' | 'green'>('course');

const holeNumbers = computed(() => {
  const count = course.value?.holesCount ?? 18;
  return Array.from({ length: count }, (_, i) => i + 1);
});

// ─── Loading ────────────────────────────────────────────────────────────────

async function onCourseChanged(next: CourseResponse | null) {
  course.value = next;
  conditions.value = [];
  greens.value = [];
  if (next) await loadAll();
}

async function loadAll() {
  if (courseId.value == null) return;
  loading.value = true;
  error.value = null;
  try {
    const [c, g] = await Promise.all([
      operationsApi.listConditions(courseId.value, props.authToken),
      operationsApi.listGreenConditions(courseId.value, props.authToken),
    ]);
    conditions.value = c;
    greens.value = g;
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tải được tình trạng sân';
  } finally {
    loading.value = false;
  }
}

// ─── Course condition form ──────────────────────────────────────────────────

const cForm = ref({
  conditionType: 'COURSE_OVERALL',
  severity: 'MODERATE',
  description: '',
  effectiveFrom: nowLocalInput(),
  expiresAt: hoursFromNowLocalInput(24),
});
const cSaving = ref(false);
const cError = ref<string | null>(null);
const cEditingId = ref<number | null>(null);

async function saveCondition() {
  if (courseId.value == null) return;
  cError.value = null;
  if (cForm.value.expiresAt && Date.parse(cForm.value.expiresAt) <= Date.parse(cForm.value.effectiveFrom)) {
    cError.value = 'Thời điểm hết hạn phải sau thời điểm hiệu lực.';
    return;
  }
  cSaving.value = true;
  try {
    const body = {
      conditionType: cForm.value.conditionType,
      severity: cForm.value.severity,
      description: cForm.value.description || undefined,
      effectiveFrom: new Date(cForm.value.effectiveFrom).toISOString(),
      expiresAt: cForm.value.expiresAt
        ? new Date(cForm.value.expiresAt).toISOString()
        : undefined,
    };
    if (cEditingId.value != null) {
      await operationsApi.updateCondition(courseId.value, cEditingId.value, body, props.authToken);
      notice.value = 'Đã cập nhật tình trạng sân.';
    } else {
      await operationsApi.createCondition(courseId.value, body, props.authToken);
      notice.value = 'Đã công bố tình trạng sân.';
    }
    cEditingId.value = null;
    await loadAll();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    cError.value = apiErr?.message ?? 'Không lưu được tình trạng sân';
  } finally {
    cSaving.value = false;
  }
}

function editCondition(c: CourseCondition) {
  cEditingId.value = c.id;
  cForm.value = {
    conditionType: c.conditionType,
    severity: c.severity,
    description: c.description ?? '',
    effectiveFrom: toLocalInput(c.effectiveFrom),
    expiresAt: toLocalInput(c.expiresAt),
  };
  cError.value = null;
}

// ─── Green condition form ───────────────────────────────────────────────────

const gForm = ref({
  holeNumber: 1,
  stimpmeter: '' as string,
  firmness: 'MEDIUM',
  moisture: 'NORMAL',
  effectiveFrom: nowLocalInput(),
  expiresAt: hoursFromNowLocalInput(24),
});
const gSaving = ref(false);
const gError = ref<string | null>(null);
const gEditingId = ref<number | null>(null);

async function saveGreen() {
  if (courseId.value == null) return;
  gError.value = null;

  const stimp = gForm.value.stimpmeter === '' ? undefined : Number(gForm.value.stimpmeter);
  if (stimp !== undefined && (Number.isNaN(stimp) || stimp < STIMPMETER_MIN || stimp > STIMPMETER_MAX)) {
    // The server enforces this range too; saying it here explains the bound
    // rather than bouncing a 400 back with a field name.
    gError.value = `Chỉ số stimpmeter phải nằm trong khoảng ${STIMPMETER_MIN}–${STIMPMETER_MAX}.`;
    return;
  }

  gSaving.value = true;
  try {
    const body = {
      stimpmeter: stimp,
      firmness: gForm.value.firmness,
      moisture: gForm.value.moisture,
      effectiveFrom: new Date(gForm.value.effectiveFrom).toISOString(),
      expiresAt: gForm.value.expiresAt
        ? new Date(gForm.value.expiresAt).toISOString()
        : undefined,
    };
    if (gEditingId.value != null) {
      await operationsApi.updateGreenCondition(
        courseId.value, gForm.value.holeNumber, gEditingId.value, body, props.authToken,
      );
      notice.value = `Đã cập nhật tình trạng green hố ${gForm.value.holeNumber}.`;
    } else {
      await operationsApi.createGreenCondition(
        courseId.value, gForm.value.holeNumber, body, props.authToken,
      );
      notice.value = `Đã ghi tình trạng green hố ${gForm.value.holeNumber}.`;
    }
    gEditingId.value = null;
    await loadAll();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    gError.value = apiErr?.message ?? 'Không lưu được tình trạng green';
  } finally {
    gSaving.value = false;
  }
}

function editGreen(g: GreenCondition) {
  gEditingId.value = g.id;
  gForm.value = {
    holeNumber: g.holeNumber,
    stimpmeter: g.stimpmeterReading?.toString() ?? '',
    firmness: g.firmness ?? 'MEDIUM',
    moisture: g.moisture ?? 'NORMAL',
    effectiveFrom: toLocalInput(g.effectiveFrom),
    expiresAt: toLocalInput(g.expiresAt),
  };
  gError.value = null;
}

// ─── Shared ─────────────────────────────────────────────────────────────────

function isLive(from: string, to?: string): boolean {
  const now = Date.now();
  return Date.parse(from) <= now && (!to || Date.parse(to) > now);
}

function fmt(iso?: string): string {
  return iso ? new Date(iso).toLocaleString('vi-VN') : '—';
}
</script>

<template>
  <div class="page">
    <header class="page-header">
      <h1 class="page-title">Tình trạng sân</h1>
      <p class="page-subtitle">
        Công bố tình trạng toàn sân và số đo từng green. Ứng dụng chỉ hiển thị
        những mục còn trong thời hạn hiệu lực.
      </p>
    </header>

    <CoursePicker
      v-model="courseId"
      :auth-token="props.authToken"
      @course-changed="onCourseChanged"
    />

    <p v-if="notice" class="notice" role="status">{{ notice }}</p>
    <p v-if="error" class="error" role="alert">
      {{ error }}
      <button type="button" class="btn-link" @click="loadAll">Thử lại</button>
    </p>

    <template v-if="courseId != null">
      <div class="tabs" role="tablist">
        <button
          type="button" class="tab" :class="{ 'tab-on': tab === 'course' }"
          role="tab" :aria-selected="tab === 'course'" @click="tab = 'course'"
        >Toàn sân ({{ conditions.length }})</button>
        <button
          type="button" class="tab" :class="{ 'tab-on': tab === 'green' }"
          role="tab" :aria-selected="tab === 'green'" @click="tab = 'green'"
        >Green từng hố ({{ greens.length }})</button>
      </div>

      <!-- ─── Course-wide ──────────────────────────────────────────────── -->
      <template v-if="tab === 'course'">
        <section class="card">
          <h2 class="card-title">
            {{ cEditingId == null ? 'Công bố tình trạng' : `Sửa mục #${cEditingId}` }}
          </h2>
          <div class="form-grid">
            <div class="field">
              <label class="label" for="cc-type">Loại</label>
              <select id="cc-type" v-model="cForm.conditionType" class="input">
                <option v-for="t in CONDITION_TYPES" :key="t" :value="t">{{ t }}</option>
              </select>
            </div>
            <div class="field">
              <label class="label" for="cc-sev">Mức độ</label>
              <select id="cc-sev" v-model="cForm.severity" class="input">
                <option v-for="s in SEVERITIES" :key="s" :value="s">{{ s }}</option>
              </select>
            </div>
            <div class="field">
              <label class="label" for="cc-from">Hiệu lực từ</label>
              <input id="cc-from" v-model="cForm.effectiveFrom" type="datetime-local" class="input" />
            </div>
            <div class="field">
              <label class="label" for="cc-to">Hết hạn</label>
              <input id="cc-to" v-model="cForm.expiresAt" type="datetime-local" class="input" />
            </div>
            <div class="field field-wide">
              <label class="label" for="cc-desc">Mô tả</label>
              <input id="cc-desc" v-model="cForm.description" class="input" placeholder="Ví dụ: chỉ đi xe trên đường bê tông" />
            </div>
          </div>
          <p v-if="cError" class="error" role="alert">{{ cError }}</p>
          <div class="actions">
            <button type="button" class="btn-primary" :disabled="cSaving" @click="saveCondition">
              {{ cSaving ? 'Đang lưu…' : cEditingId == null ? 'Công bố' : 'Lưu thay đổi' }}
            </button>
            <button v-if="cEditingId != null" type="button" class="btn-secondary" @click="cEditingId = null">Huỷ</button>
          </div>
        </section>

        <section class="card">
          <h2 class="card-title">Đã công bố</h2>
          <p v-if="loading" class="muted">Đang tải…</p>
          <p v-else-if="conditions.length === 0" class="muted">Chưa có tình trạng nào được công bố.</p>
          <table v-else class="table">
            <thead>
              <tr><th>Loại</th><th>Mức độ</th><th>Mô tả</th><th>Khoảng hiệu lực</th><th>Trạng thái</th><th></th></tr>
            </thead>
            <tbody>
              <tr v-for="c in conditions" :key="c.id">
                <td>{{ c.conditionType }}</td>
                <td>{{ c.severity }}</td>
                <td>{{ c.description ?? '—' }}</td>
                <td>{{ fmt(c.effectiveFrom) }} → {{ fmt(c.expiresAt) }}</td>
                <td>
                  <span :class="isLive(c.effectiveFrom, c.expiresAt) ? 'badge-active' : 'badge-idle'">
                    {{ isLive(c.effectiveFrom, c.expiresAt) ? 'Đang hiệu lực' : 'Ngoài hiệu lực' }}
                  </span>
                </td>
                <td><button type="button" class="btn-link" @click="editCondition(c)">Sửa</button></td>
              </tr>
            </tbody>
          </table>
        </section>
      </template>

      <!-- ─── Per green ────────────────────────────────────────────────── -->
      <template v-else>
        <section class="card">
          <h2 class="card-title">
            {{ gEditingId == null ? 'Ghi số đo green' : `Sửa số đo #${gEditingId}` }}
          </h2>
          <div class="form-grid">
            <div class="field">
              <label class="label" for="gc-hole">Hố</label>
              <select id="gc-hole" v-model.number="gForm.holeNumber" class="input">
                <option v-for="n in holeNumbers" :key="n" :value="n">{{ n }}</option>
              </select>
            </div>
            <div class="field">
              <label class="label" for="gc-stimp">Stimpmeter ({{ STIMPMETER_MIN }}–{{ STIMPMETER_MAX }})</label>
              <input id="gc-stimp" v-model="gForm.stimpmeter" class="input" inputmode="decimal" placeholder="10.5" />
            </div>
            <div class="field">
              <label class="label" for="gc-firm">Độ cứng</label>
              <select id="gc-firm" v-model="gForm.firmness" class="input">
                <option v-for="f in FIRMNESS" :key="f" :value="f">{{ f }}</option>
              </select>
            </div>
            <div class="field">
              <label class="label" for="gc-moist">Độ ẩm</label>
              <select id="gc-moist" v-model="gForm.moisture" class="input">
                <option v-for="m in MOISTURE" :key="m" :value="m">{{ m }}</option>
              </select>
            </div>
            <div class="field">
              <label class="label" for="gc-from">Hiệu lực từ</label>
              <input id="gc-from" v-model="gForm.effectiveFrom" type="datetime-local" class="input" />
            </div>
            <div class="field">
              <label class="label" for="gc-to">Hết hạn</label>
              <input id="gc-to" v-model="gForm.expiresAt" type="datetime-local" class="input" />
            </div>
          </div>
          <p v-if="gError" class="error" role="alert">{{ gError }}</p>
          <div class="actions">
            <button type="button" class="btn-primary" :disabled="gSaving" @click="saveGreen">
              {{ gSaving ? 'Đang lưu…' : gEditingId == null ? 'Ghi số đo' : 'Lưu thay đổi' }}
            </button>
            <button v-if="gEditingId != null" type="button" class="btn-secondary" @click="gEditingId = null">Huỷ</button>
          </div>
        </section>

        <section class="card">
          <h2 class="card-title">Số đo đã ghi</h2>
          <p v-if="loading" class="muted">Đang tải…</p>
          <p v-else-if="greens.length === 0" class="muted">Chưa có số đo green nào.</p>
          <table v-else class="table">
            <thead>
              <tr><th>Hố</th><th>Stimpmeter</th><th>Độ cứng</th><th>Độ ẩm</th><th>Khoảng hiệu lực</th><th>Trạng thái</th><th></th></tr>
            </thead>
            <tbody>
              <tr v-for="g in greens" :key="g.id">
                <td>{{ g.holeNumber }}</td>
                <td>{{ g.stimpmeterReading ?? '—' }}</td>
                <td>{{ g.firmness ?? '—' }}</td>
                <td>{{ g.moisture ?? '—' }}</td>
                <td>{{ fmt(g.effectiveFrom) }} → {{ fmt(g.expiresAt) }}</td>
                <td>
                  <span :class="isLive(g.effectiveFrom, g.expiresAt) ? 'badge-active' : 'badge-idle'">
                    {{ isLive(g.effectiveFrom, g.expiresAt) ? 'Đang hiệu lực' : 'Ngoài hiệu lực' }}
                  </span>
                </td>
                <td><button type="button" class="btn-link" @click="editGreen(g)">Sửa</button></td>
              </tr>
            </tbody>
          </table>
        </section>
      </template>
    </template>
  </div>
</template>

<style scoped>
.page { padding: 24px; max-width: 1100px; }
.page-title { margin: 0 0 4px; font-size: 22px; }
.page-subtitle { margin: 0 0 20px; color: var(--muted); font-size: 14px; }
.tabs { display: flex; gap: 4px; margin-bottom: 12px; }
.tab { border: 1px solid var(--outline-variant); background: var(--surface-container-low); border-radius: 6px; padding: 6px 14px; cursor: pointer; font-size: 14px; }
.tab-on { background: var(--primary); color: #fff; border-color: var(--primary-bright); }
.card { background: var(--surface-container-low); border: 1px solid var(--border); border-radius: 8px; padding: 16px; margin-bottom: 16px; }
.card-title { margin: 0 0 12px; font-size: 16px; }
.form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.field { display: flex; flex-direction: column; gap: 4px; }
.field-wide { grid-column: 1 / -1; }
.label { font-size: 12px; font-weight: 600; color: var(--muted); }
.input { padding: 8px 10px; border: 1px solid var(--outline-variant); border-radius: 6px; font-size: 14px; font-family: inherit; background: var(--surface-container-lowest); color: var(--on-surface); color-scheme: dark; }
.input option { background: var(--surface-container); color: var(--on-surface); }
.actions { display: flex; gap: 8px; margin-top: 12px; }
.btn-primary { background: var(--primary); color: #fff; border: none; border-radius: 6px; padding: 8px 16px; font-weight: 600; cursor: pointer; }
.btn-primary:disabled { opacity: 0.6; cursor: default; }
.btn-secondary { background: transparent; border: 1px solid var(--outline-variant); border-radius: 6px; padding: 8px 16px; cursor: pointer; }
.btn-link { background: none; border: none; color: var(--primary-bright); cursor: pointer; padding: 0 4px; }
.table { width: 100%; border-collapse: collapse; font-size: 14px; }
.table th, .table td { text-align: left; padding: 8px; border-bottom: 1px solid var(--border); }
.muted { color: var(--muted); font-size: 14px; }
.error { color: var(--error); font-size: 13px; }
.notice { color: var(--tertiary); font-size: 13px; }
.badge-active { background: var(--tertiary-container); color: var(--on-tertiary); border-radius: 4px; padding: 2px 8px; font-size: 12px; }
.badge-idle { background: var(--surface-container-high); color: var(--on-surface); border-radius: 4px; padding: 2px 8px; font-size: 12px; }
</style>
