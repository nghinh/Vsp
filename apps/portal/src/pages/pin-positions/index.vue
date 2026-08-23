<script setup lang="ts">
/**
 * Pin positions — where the hole is cut, per hole, per day.
 *
 * This page was a placeholder that named four endpoints under
 * `/courses/{courseId}/pin-positions`. None of them exist. The real ones are
 * `/admin/courses/{courseId}/holes/{holeNumber}/pins`, and they have been
 * there, complete and unused, the whole time — so the feature read as
 * "backend not ready" when what was missing was this file.
 *
 * Two things this page insists on, because a pin is a number a golfer plays a
 * shot to:
 *
 *   • Every pin carries an expiry. The server requires it, and so it should:
 *     a pin left from last Tuesday quoted as today's is worse than no pin,
 *     because the app cannot tell it is stale.
 *   • The pin is placed by clicking the green on satellite imagery. The first
 *     version asked for latitude and longitude in two text boxes, which is a
 *     coordinate entry form and not a pin placement tool — a greenkeeper knows
 *     where the hole is cut because they cut it, not as 10.861240. The numbers
 *     remain beside the map as a readout and for nudging.
 */
import { computed, ref } from 'vue';

import { operationsApi } from '@/api/admin/operations';
import CoursePicker from '@/components/CoursePicker.vue';
import PinMapPicker from '@/components/PinMapPicker.vue';
import { endOfTodayLocalInput, nowLocalInput, toLocalInput } from '@/lib/datetime';
import { parsePoint, pointToWkt } from '@/lib/wkt';
import type { CourseResponse } from '@/types/admin/course';
import type { PinPosition } from '@/types/admin/operations';
import { PIN_POSITION_TYPES } from '@/types/admin/operations';
import { pinPositionTypeLabel } from '@/lib/enum-labels';

const props = defineProps<{ authToken: string }>();

const courseId = ref<number | null>(null);
const course = ref<CourseResponse | null>(null);
const pins = ref<PinPosition[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);
const notice = ref<string | null>(null);

// ─── Form ───────────────────────────────────────────────────────────────────

const form = ref({
  holeNumber: 1,
  latitude: '' as string,
  longitude: '' as string,
  pinPositionType: 'CURRENT',
  effectiveFrom: nowLocalInput(),
  expiresAt: endOfTodayLocalInput(),
});

const saving = ref(false);
const formError = ref<string | null>(null);
const editingId = ref<number | null>(null);

const holeNumbers = computed(() => {
  const count = course.value?.holesCount ?? 18;
  return Array.from({ length: count }, (_, i) => i + 1);
});

/** Pins whose window covers right now — what the app is serving today. */
const activePins = computed(() => {
  const now = Date.now();
  return pins.value.filter(
    (p) =>
      Date.parse(p.effectiveFrom) <= now &&
      (!p.expiresAt || Date.parse(p.expiresAt) > now),
  );
});

/** Where to open the map: the course's own point. */
const courseCentre = computed(() => {
  // /admin/courses returns hex EWKB here, not WKT — see lib/wkt.ts.
  const at = parsePoint(course.value?.location ?? null);
  return at ? { latitude: at.latitude, longitude: at.longitude } : null;
});

/** Existing pins as points, for context under the one being placed. */
const pinPoints = computed(() =>
  pins.value
    .map((p) => ({ at: parsePoint(p.position), holeNumber: p.holeNumber }))
    .filter((p): p is { at: { latitude: number; longitude: number }; holeNumber: number } => p.at !== null)
    .map((p) => ({ ...p.at, holeNumber: p.holeNumber })),
);

/**
 * The stored geometry, as coordinates.
 *
 * This column used to print `pin.position` straight through, which for the
 * endpoints that return EWKB meant a 50-character hex string in a table an
 * operator is meant to read a pin off. Falling back to the raw value keeps an
 * unparseable geometry visible rather than blank — but it should not be the
 * normal case.
 */
function formatPosition(position: string): string {
  const at = parsePoint(position);
  return at ? `${at.latitude.toFixed(6)}, ${at.longitude.toFixed(6)}` : position;
}

function onPicked(point: { latitude: number; longitude: number }) {
  form.value.latitude = point.latitude.toFixed(7);
  form.value.longitude = point.longitude.toFixed(7);
  formError.value = null;
}

const holesWithoutPin = computed(() => {
  const covered = new Set(activePins.value.map((p) => p.holeNumber));
  return holeNumbers.value.filter((n) => !covered.has(n));
});

// ─── Loading ────────────────────────────────────────────────────────────────

async function onCourseChanged(next: CourseResponse | null) {
  course.value = next;
  pins.value = [];
  if (next) await loadPins();
}

async function loadPins() {
  if (courseId.value == null) return;
  loading.value = true;
  error.value = null;
  try {
    pins.value = await operationsApi.listCoursePins(courseId.value, props.authToken);
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tải được danh sách vị trí cờ';
  } finally {
    loading.value = false;
  }
}

// ─── Saving ─────────────────────────────────────────────────────────────────

function validate(): boolean {
  formError.value = null;
  const lat = Number(form.value.latitude);
  const lng = Number(form.value.longitude);

  if (!form.value.latitude || !form.value.longitude) {
    formError.value = 'Cần cả vĩ độ và kinh độ.';
  } else if (Number.isNaN(lat) || lat < -90 || lat > 90) {
    formError.value = 'Vĩ độ phải nằm trong khoảng -90 đến 90.';
  } else if (Number.isNaN(lng) || lng < -180 || lng > 180) {
    formError.value = 'Kinh độ phải nằm trong khoảng -180 đến 180.';
  } else if (!form.value.expiresAt) {
    // The server rejects this too. Saying so here saves a round trip and
    // explains *why*, which the server error does not.
    formError.value = 'Cần thời điểm hết hạn — một vị trí cờ không có hạn sẽ bị ứng dụng coi là của hôm nay mãi mãi.';
  } else if (Date.parse(form.value.expiresAt) <= Date.parse(form.value.effectiveFrom)) {
    formError.value = 'Thời điểm hết hạn phải sau thời điểm hiệu lực.';
  }
  return formError.value === null;
}

async function save() {
  if (courseId.value == null || !validate()) return;
  saving.value = true;
  try {
    const body = {
      position: pointToWkt(Number(form.value.latitude), Number(form.value.longitude)),
      pinPositionType: form.value.pinPositionType,
      effectiveFrom: new Date(form.value.effectiveFrom).toISOString(),
      expiresAt: new Date(form.value.expiresAt).toISOString(),
    };
    if (editingId.value != null) {
      await operationsApi.updatePin(
        courseId.value, form.value.holeNumber, editingId.value, body, props.authToken,
      );
      notice.value = `Đã cập nhật vị trí cờ hố ${form.value.holeNumber}.`;
    } else {
      await operationsApi.createPin(
        courseId.value, form.value.holeNumber, body, props.authToken,
      );
      notice.value = `Đã đặt vị trí cờ hố ${form.value.holeNumber}.`;
    }
    editingId.value = null;
    await loadPins();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    formError.value = apiErr?.message ?? 'Không lưu được vị trí cờ';
  } finally {
    saving.value = false;
  }
}

function edit(pin: PinPosition) {
  const at = parsePoint(pin.position);
  editingId.value = pin.id;
  form.value = {
    holeNumber: pin.holeNumber,
    latitude: at ? String(at.latitude) : '',
    longitude: at ? String(at.longitude) : '',
    pinPositionType: pin.pinPositionType ?? 'CURRENT',
    effectiveFrom: toLocalInput(pin.effectiveFrom),
    expiresAt: toLocalInput(pin.expiresAt),
  };
  formError.value = null;
}

function cancelEdit() {
  editingId.value = null;
  formError.value = null;
}

function formatWindow(pin: PinPosition): string {
  const from = new Date(pin.effectiveFrom).toLocaleString('vi-VN');
  const to = pin.expiresAt ? new Date(pin.expiresAt).toLocaleString('vi-VN') : '—';
  return `${from} → ${to}`;
}

function isActive(pin: PinPosition): boolean {
  const now = Date.now();
  return (
    Date.parse(pin.effectiveFrom) <= now &&
    (!pin.expiresAt || Date.parse(pin.expiresAt) > now)
  );
}
</script>

<template>
  <div class="page">
    <header class="page-header">
      <h1 class="page-title">Vị trí cắm cờ</h1>
      <p class="page-subtitle">
        Đặt và lên lịch vị trí cờ theo hố. Ứng dụng của golfer chỉ dùng vị trí còn
        trong thời hạn hiệu lực.
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
      <button type="button" class="btn-link" @click="loadPins">Thử lại</button>
    </p>

    <template v-if="courseId != null">
      <!-- ─── Coverage ─────────────────────────────────────────────────── -->
      <section class="card">
        <h2 class="card-title">Hôm nay</h2>
        <p v-if="loading" class="muted">Đang tải…</p>
        <template v-else>
          <p class="coverage">
            <strong>{{ activePins.length }}</strong> / {{ holeNumbers.length }} hố có vị trí cờ đang hiệu lực.
          </p>
          <p v-if="holesWithoutPin.length" class="muted">
            Chưa đặt: {{ holesWithoutPin.join(', ') }}
          </p>
        </template>
      </section>

      <!-- ─── Form ─────────────────────────────────────────────────────── -->
      <section class="card">
        <h2 class="card-title">
          {{ editingId == null ? 'Đặt vị trí cờ' : `Sửa vị trí cờ #${editingId}` }}
        </h2>

        <div class="form-grid">
          <PinMapPicker
            :latitude="form.latitude === '' ? null : Number(form.latitude)"
            :longitude="form.longitude === '' ? null : Number(form.longitude)"
            :centre="courseCentre"
            :existing="pinPoints"
            @picked="onPicked"
          />

          <div class="field">
            <label class="label" for="pp-hole">Hố</label>
            <select id="pp-hole" v-model.number="form.holeNumber" class="input">
              <option v-for="n in holeNumbers" :key="n" :value="n">{{ n }}</option>
            </select>
          </div>

          <div class="field">
            <label class="label" for="pp-type">Loại</label>
            <select id="pp-type" v-model="form.pinPositionType" class="input">
              <option v-for="t in PIN_POSITION_TYPES" :key="t" :value="t">{{ pinPositionTypeLabel(t) }}</option>
            </select>
          </div>

          <div class="field">
            <label class="label" for="pp-lat">Vĩ độ</label>
            <input id="pp-lat" v-model="form.latitude" class="input" inputmode="decimal" placeholder="10.861240" />
          </div>

          <div class="field">
            <label class="label" for="pp-lng">Kinh độ</label>
            <input id="pp-lng" v-model="form.longitude" class="input" inputmode="decimal" placeholder="106.896005" />
          </div>

          <div class="field">
            <label class="label" for="pp-from">Hiệu lực từ</label>
            <input id="pp-from" v-model="form.effectiveFrom" type="datetime-local" class="input" />
          </div>

          <div class="field">
            <label class="label" for="pp-to">Hết hạn</label>
            <input id="pp-to" v-model="form.expiresAt" type="datetime-local" class="input" />
          </div>
        </div>

        <p v-if="formError" class="error" role="alert">{{ formError }}</p>

        <div class="actions">
          <button type="button" class="btn-primary" :disabled="saving" @click="save">
            {{ saving ? 'Đang lưu…' : editingId == null ? 'Đặt vị trí' : 'Lưu thay đổi' }}
          </button>
          <button v-if="editingId != null" type="button" class="btn-secondary" @click="cancelEdit">
            Huỷ
          </button>
        </div>
      </section>

      <!-- ─── List ─────────────────────────────────────────────────────── -->
      <section class="card">
        <h2 class="card-title">Đã lên lịch</h2>
        <p v-if="loading" class="muted">Đang tải…</p>
        <p v-else-if="pins.length === 0" class="muted">Sân này chưa có vị trí cờ nào.</p>
        <div class="table-scroll" v-else>
        <table class="table">
          <thead>
            <tr>
              <th>Hố</th>
              <th>Loại</th>
              <th>Toạ độ</th>
              <th>Khoảng hiệu lực</th>
              <th>Trạng thái</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="pin in pins" :key="pin.id">
              <td>{{ pin.holeNumber }}</td>
              <td>{{ pinPositionTypeLabel(pin.pinPositionType) }}</td>
              <td class="mono">{{ formatPosition(pin.position) }}</td>
              <td>{{ formatWindow(pin) }}</td>
              <td>
                <span :class="isActive(pin) ? 'badge-active' : 'badge-idle'">
                  {{ isActive(pin) ? 'Đang hiệu lực' : 'Ngoài hiệu lực' }}
                </span>
              </td>
              <td><button type="button" class="btn-link" @click="edit(pin)">Sửa</button></td>
            </tr>
          </tbody>
        </table>
        </div>
      </section>
    </template>
  </div>
</template>

<style scoped>
.page { padding: 24px; max-width: 1100px; }
.page-title { margin: 0 0 4px; font-size: 22px; }
.page-subtitle { margin: 0 0 20px; color: var(--muted); font-size: 14px; }
.card { background: var(--surface-container-low); border: 1px solid var(--border); border-radius: 8px; padding: 16px; margin-bottom: 16px; }
.card-title { margin: 0 0 12px; font-size: 16px; }
.form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.field { display: flex; flex-direction: column; gap: 4px; }
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
.mono { font-family: ui-monospace, monospace; font-size: 12px; }
.muted { color: var(--muted); font-size: 14px; }
.coverage { margin: 0 0 4px; font-size: 14px; }
.error { color: var(--error); font-size: 13px; }
.notice { color: var(--tertiary); font-size: 13px; }
.badge-active { background: var(--tertiary-container); color: var(--on-tertiary); border-radius: 4px; padding: 2px 8px; font-size: 12px; }
.badge-idle { background: var(--surface-container-high); color: var(--on-surface); border-radius: 4px; padding: 2px 8px; font-size: 12px; }
</style>
