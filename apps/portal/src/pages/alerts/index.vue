<script setup lang="ts">
/**
 * Course alerts — safety and operational notices pushed to golfers on course.
 *
 * The server has had a complete alert controller — send, list with filters,
 * edit, cancel, acknowledge — since before this page existed, and nothing
 * called it. The placeholder that stood here named `/courses/{id}/alerts`,
 * which is not a path the API serves.
 *
 * The one thing this page is careful about is the target. An alert goes to a
 * facility, a course, a hole, a flight or a group, and the server takes each
 * as a separate optional id. Sending a lightning warning to the wrong scope is
 * either a panic nobody needed or a warning that never reached the four people
 * standing under the tree, so the form makes the scope an explicit choice
 * rather than five fields the sender has to remember to leave blank.
 */
import { computed, onMounted, ref, watch } from 'vue';

import {
  ALERT_PRIORITIES,
  ALERT_TARGET_TYPES,
  ALERT_TYPES,
  DELIVERY_STATUSES,
  alertApi,
} from '@/api/admin/alerts';
import {
  alertPriorityLabel,
  alertTargetLabel,
  alertTypeLabel,
  deliveryStatusLabel,
} from '@/lib/enum-labels';
import { courseAdminApi } from '@/api/admin/courses';
import { facilityAdminApi } from '@/api/admin/facilities';
import { holeAdminApi } from '@/api/admin/holes';
import { nowLocalInput } from '@/lib/datetime';
import type { CourseResponse } from '@/types/admin/course';
import type { FacilityResponse } from '@/types/admin/facility';
import type { HoleResponse } from '@/types/admin/hole';
import type {
  AlertListFilters,
  AlertTargetType,
  AlertType,
  CourseAlert,
  DeliveryStatus,
} from '@/api/admin/alerts';

const props = defineProps<{ authToken: string }>();

const alerts = ref<CourseAlert[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);
const notice = ref<string | null>(null);

const filters = ref<AlertListFilters>({});

// ─── Compose ────────────────────────────────────────────────────────────────

const form = ref({
  alertType: 'SAFETY' as AlertType,
  targetType: 'COURSE' as AlertTargetType,
  targetId: '',
  title: '',
  body: '',
  priority: 'NORMAL',
  effectiveAt: nowLocalInput(),
  expiresAt: '',
  acknowledgmentRequired: false,
});

/**
 * The scope, chosen rather than typed.
 *
 * This field used to be a text box labelled "UUID". Three of the five scopes
 * are not UUIDs at all — facility, course and hole are numeric row ids (the
 * server stored them as UUID until V35, so no value an operator could type was
 * ever going to match) — and the other two are ids nobody carries in their
 * head. For a form whose failure mode is a lightning warning reaching the
 * wrong people, or nobody, the target has to be picked from what exists.
 */
const facilities = ref<FacilityResponse[]>([]);
const scopeCourses = ref<CourseResponse[]>([]);
const scopeHoles = ref<HoleResponse[]>([]);
const scopeFacilityId = ref<number | null>(null);
const scopeCourseId = ref<number | null>(null);

/** True for the scopes that are still an id the operator has to supply. */
const scopeIsFreeText = computed(
  () => form.value.targetType === 'FLIGHT' || form.value.targetType === 'GROUP',
);

async function loadScopeCourses(facilityId: number | null) {
  scopeCourses.value = [];
  scopeHoles.value = [];
  scopeCourseId.value = null;
  if (facilityId == null) return;
  scopeCourses.value = await courseAdminApi.listCourses(facilityId, props.authToken);
  if (scopeCourses.value.length === 1) scopeCourseId.value = scopeCourses.value[0].id;
}

async function loadScopeHoles(courseId: number | null) {
  scopeHoles.value = [];
  if (courseId == null) return;
  scopeHoles.value = await holeAdminApi.listHoles(courseId, props.authToken);
}

watch(scopeFacilityId, (id) => {
  void loadScopeCourses(id);
  if (form.value.targetType === 'FACILITY') form.value.targetId = id == null ? '' : String(id);
});

watch(scopeCourseId, (id) => {
  void loadScopeHoles(id);
  if (form.value.targetType === 'COURSE') form.value.targetId = id == null ? '' : String(id);
});

// Changing the scope invalidates whatever id was chosen for the previous one —
// a course id left behind in a HOLE-scoped alert would address a real but
// entirely different row.
watch(
  () => form.value.targetType,
  (type) => {
    form.value.targetId =
      type === 'FACILITY' && scopeFacilityId.value != null
        ? String(scopeFacilityId.value)
        : type === 'COURSE' && scopeCourseId.value != null
          ? String(scopeCourseId.value)
          : '';
  },
);

const sending = ref(false);
const formError = ref<string | null>(null);

/** The server takes one id per scope; the form takes a scope and one id. */
function targetField(): Record<string, string> {
  const key = {
    FACILITY: 'facilityId',
    COURSE: 'courseId',
    HOLE: 'holeId',
    FLIGHT: 'flightId',
    GROUP: 'groupId',
  }[form.value.targetType];
  return { [key]: form.value.targetId };
}

function validate(): boolean {
  formError.value = null;
  if (!form.value.title.trim()) formError.value = 'Cần tiêu đề.';
  else if (!form.value.body.trim()) formError.value = 'Cần nội dung.';
  else if (!form.value.targetId.trim())
    formError.value = scopeIsFreeText.value
      ? 'Cần id của phạm vi gửi — không có nó thì cảnh báo không tới được ai.'
      : 'Chọn nơi nhận cảnh báo.';
  else if (
    form.value.expiresAt &&
    Date.parse(form.value.expiresAt) <= Date.parse(form.value.effectiveAt)
  )
    formError.value = 'Thời điểm hết hạn phải sau thời điểm hiệu lực.';
  return formError.value === null;
}

async function send() {
  if (!validate()) return;
  sending.value = true;
  try {
    await alertApi.create(props.authToken, {
      ...targetField(),
      alertType: form.value.alertType,
      title: form.value.title.trim(),
      body: form.value.body.trim(),
      priority: form.value.priority,
      effectiveAt: new Date(form.value.effectiveAt).toISOString(),
      expiresAt: form.value.expiresAt
        ? new Date(form.value.expiresAt).toISOString()
        : undefined,
      acknowledgmentRequired: form.value.acknowledgmentRequired,
    });
    notice.value = 'Đã gửi cảnh báo.';
    form.value.title = '';
    form.value.body = '';
    await load();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    formError.value = apiErr?.message ?? 'Không gửi được cảnh báo';
  } finally {
    sending.value = false;
  }
}

// ─── List ───────────────────────────────────────────────────────────────────

async function load() {
  loading.value = true;
  error.value = null;
  try {
    const resp = await alertApi.list(props.authToken, filters.value);
    alerts.value = resp.alerts ?? [];
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tải được danh sách cảnh báo';
  } finally {
    loading.value = false;
  }
}

async function cancel(alert: CourseAlert) {
  error.value = null;
  try {
    await alertApi.cancel(props.authToken, alert.id);
    notice.value = `Đã huỷ cảnh báo “${alert.title}”.`;
    await load();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không huỷ được cảnh báo';
  }
}

const pendingCount = computed(
  () => alerts.value.filter((a) => a.deliveryStatus === 'PENDING').length,
);

function fmt(iso?: string): string {
  return iso ? new Date(iso).toLocaleString('vi-VN') : '—';
}

function statusClass(s?: DeliveryStatus): string {
  if (s === 'DELIVERED') return 'badge-ok';
  if (s === 'FAILED') return 'badge-bad';
  return 'badge-idle';
}

onMounted(async () => {
  await load();
  try {
    facilities.value = await facilityAdminApi.listFacilities(props.authToken);
  } catch {
    // The alert list is the page's job; a facility list that failed to load
    // shows as an empty picker, which the send button already refuses.
    facilities.value = [];
  }
});
</script>

<template>
  <div class="page">
    <header class="page-header">
      <h1 class="page-title">Cảnh báo sân</h1>
      <p class="page-subtitle">
        Gửi thông báo an toàn và vận hành tới golfer đang trên sân, theo phạm vi
        cơ sở, sân, hố, nhóm hoặc flight.
      </p>
    </header>

    <p v-if="notice" class="notice" role="status">{{ notice }}</p>
    <p v-if="error" class="error" role="alert">
      {{ error }}
      <button type="button" class="btn-link" @click="load">Thử lại</button>
    </p>

    <!-- ─── Compose ──────────────────────────────────────────────────────── -->
    <section class="card">
      <h2 class="card-title">Gửi cảnh báo</h2>
      <div class="form-grid">
        <div class="field">
          <label class="label" for="al-type">Loại</label>
          <select id="al-type" v-model="form.alertType" class="input">
            <option v-for="t in ALERT_TYPES" :key="t" :value="t">{{ alertTypeLabel(t) }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label" for="al-scope">Phạm vi</label>
          <select id="al-scope" v-model="form.targetType" class="input">
            <option v-for="t in ALERT_TARGET_TYPES" :key="t" :value="t">{{ alertTargetLabel(t) }}</option>
          </select>
        </div>
        <div v-if="!scopeIsFreeText" class="field">
          <label class="label" for="al-facility">Cơ sở</label>
          <select id="al-facility" v-model="scopeFacilityId" class="input">
            <option :value="null">— Chọn cơ sở —</option>
            <option v-for="f in facilities" :key="f.id" :value="f.id">{{ f.name }}</option>
          </select>
        </div>
        <div v-if="!scopeIsFreeText && form.targetType !== 'FACILITY'" class="field">
          <label class="label" for="al-course">Sân</label>
          <select
            id="al-course"
            v-model="scopeCourseId"
            class="input"
            :disabled="scopeCourses.length === 0"
          >
            <option :value="null">— Chọn sân —</option>
            <option v-for="c in scopeCourses" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
        <div v-if="form.targetType === 'HOLE'" class="field">
          <label class="label" for="al-hole">Hố</label>
          <select
            id="al-hole"
            v-model="form.targetId"
            class="input"
            :disabled="scopeHoles.length === 0"
          >
            <option value="">— Chọn hố —</option>
            <option v-for="h in scopeHoles" :key="h.id" :value="String(h.id)">
              Hố {{ h.holeNumber }}
            </option>
          </select>
        </div>
        <div v-if="scopeIsFreeText" class="field">
          <label class="label" for="al-target">Id {{ form.targetType === 'FLIGHT' ? 'flight' : 'nhóm' }}</label>
          <input id="al-target" v-model="form.targetId" class="input" placeholder="UUID" />
        </div>
        <div class="field">
          <label class="label" for="al-pri">Mức ưu tiên</label>
          <select id="al-pri" v-model="form.priority" class="input">
            <option v-for="p in ALERT_PRIORITIES" :key="p" :value="p">{{ alertPriorityLabel(p) }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label" for="al-from">Hiệu lực từ</label>
          <input id="al-from" v-model="form.effectiveAt" type="datetime-local" class="input" />
        </div>
        <div class="field">
          <label class="label" for="al-to">Hết hạn</label>
          <input id="al-to" v-model="form.expiresAt" type="datetime-local" class="input" />
        </div>
        <div class="field field-wide">
          <label class="label" for="al-title">Tiêu đề</label>
          <input id="al-title" v-model="form.title" class="input" maxlength="120" placeholder="Ví dụ: Tạm dừng thi đấu do sét" />
        </div>
        <div class="field field-wide">
          <label class="label" for="al-body">Nội dung</label>
          <textarea id="al-body" v-model="form.body" class="input" rows="3" maxlength="500"></textarea>
        </div>
        <div class="field field-wide check">
          <label>
            <input v-model="form.acknowledgmentRequired" type="checkbox" />
            Yêu cầu golfer xác nhận đã đọc
          </label>
        </div>
      </div>

      <p v-if="formError" class="error" role="alert">{{ formError }}</p>

      <div class="actions">
        <button type="button" class="btn-primary" :disabled="sending" @click="send">
          {{ sending ? 'Đang gửi…' : 'Gửi cảnh báo' }}
        </button>
      </div>
    </section>

    <!-- ─── List ─────────────────────────────────────────────────────────── -->
    <section class="card">
      <div class="card-head">
        <h2 class="card-title">Đã gửi</h2>
        <span v-if="pendingCount" class="badge-idle">{{ pendingCount }} đang chờ gửi</span>
      </div>

      <div class="filters">
        <select v-model="filters.alertType" class="input" aria-label="Lọc theo loại" @change="load">
          <option :value="undefined">Mọi loại</option>
          <option v-for="t in ALERT_TYPES" :key="t" :value="t">{{ alertTypeLabel(t) }}</option>
        </select>
        <select v-model="filters.deliveryStatus" class="input" aria-label="Lọc theo trạng thái" @change="load">
          <option :value="undefined">Mọi trạng thái</option>
          <option v-for="s in DELIVERY_STATUSES" :key="s" :value="s">{{ deliveryStatusLabel(s) }}</option>
        </select>
      </div>

      <p v-if="loading" class="muted">Đang tải…</p>
      <p v-else-if="alerts.length === 0" class="muted">Chưa có cảnh báo nào.</p>
      <div class="table-scroll" v-else>
      <table class="table">
        <thead>
          <tr><th>Tiêu đề</th><th>Loại</th><th>Hiệu lực</th><th>Hết hạn</th><th>Trạng thái</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="a in alerts" :key="a.id">
            <td>
              <strong>{{ a.title }}</strong>
              <p class="body-preview">{{ a.body }}</p>
            </td>
            <td>{{ alertTypeLabel(a.alertType) }}</td>
            <td>{{ fmt(a.effectiveAt) }}</td>
            <td>{{ fmt(a.expiresAt) }}</td>
            <td><span :class="statusClass(a.deliveryStatus)">{{ deliveryStatusLabel(a.deliveryStatus) }}</span></td>
            <td><button type="button" class="btn-link danger" @click="cancel(a)">Huỷ</button></td>
          </tr>
        </tbody>
      </table>
      </div>
    </section>
  </div>
</template>

<style scoped>
.page { padding: 24px; max-width: 1100px; }
.page-title { margin: 0 0 4px; font-size: 22px; }
.page-subtitle { margin: 0 0 20px; color: var(--muted); font-size: 14px; }
.card { background: var(--surface-container-low); border: 1px solid var(--border); border-radius: 8px; padding: 16px; margin-bottom: 16px; }
.card-head { display: flex; align-items: center; gap: 12px; }
.card-title { margin: 0 0 12px; font-size: 16px; }
.filters { display: flex; gap: 8px; margin-bottom: 12px; }
.form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.field { display: flex; flex-direction: column; gap: 4px; }
.field-wide { grid-column: 1 / -1; }
.check label { font-size: 14px; display: flex; gap: 8px; align-items: center; }
.label { font-size: 12px; font-weight: 600; color: var(--muted); }
.input { padding: 8px 10px; border: 1px solid var(--outline-variant); border-radius: 6px; font-size: 14px; font-family: inherit; background: var(--surface-container-lowest); color: var(--on-surface); color-scheme: dark; }
.input option { background: var(--surface-container); color: var(--on-surface); }
.actions { display: flex; gap: 8px; margin-top: 12px; }
.btn-primary { background: var(--primary); color: #fff; border: none; border-radius: 6px; padding: 8px 16px; font-weight: 600; cursor: pointer; }
.btn-primary:disabled { opacity: 0.6; cursor: default; }
.btn-link { background: none; border: none; color: var(--primary-bright); cursor: pointer; padding: 0 4px; }
.btn-link.danger { color: var(--error); }
.table { width: 100%; border-collapse: collapse; font-size: 14px; }
.table th, .table td { text-align: left; padding: 8px; border-bottom: 1px solid var(--border); vertical-align: top; }
.body-preview { margin: 2px 0 0; color: var(--muted); font-size: 13px; }
.muted { color: var(--muted); font-size: 14px; }
.error { color: var(--error); font-size: 13px; }
.notice { color: var(--tertiary); font-size: 13px; }
.badge-ok { background: var(--tertiary-container); color: var(--on-tertiary); border-radius: 4px; padding: 2px 8px; font-size: 12px; }
.badge-bad { background: var(--error-container); color: var(--on-error-container); border-radius: 4px; padding: 2px 8px; font-size: 12px; }
.badge-idle { background: var(--surface-container-high); color: var(--on-surface); border-radius: 4px; padding: 2px 8px; font-size: 12px; }
</style>
