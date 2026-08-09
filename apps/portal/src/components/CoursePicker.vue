<script setup lang="ts">
/**
 * Facility → course selector.
 *
 * The greenkeeping pages are routed without a course in the path
 * (/pin-positions, /course-conditions), so each one has to ask which course
 * before it can ask anything else. Three copies of that would drift; this is
 * the one copy.
 *
 * It reports a failure rather than rendering an empty list. An operator who
 * sees "no courses" and an operator whose request failed would take very
 * different actions, and the two must not look the same.
 */
import { onMounted, ref, watch } from 'vue';

import { courseAdminApi } from '@/api/admin/courses';
import { facilityAdminApi } from '@/api/admin/facilities';
import type { CourseResponse } from '@/types/admin/course';
import type { FacilityResponse } from '@/types/admin/facility';

const props = defineProps<{
  authToken: string;
  modelValue: number | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', courseId: number | null): void;
  (e: 'course-changed', course: CourseResponse | null): void;
}>();

const facilities = ref<FacilityResponse[]>([]);
const courses = ref<CourseResponse[]>([]);
const facilityId = ref<number | null>(null);
const loading = ref(false);
const error = ref<string | null>(null);

async function loadFacilities() {
  loading.value = true;
  error.value = null;
  try {
    facilities.value = await facilityAdminApi.listFacilities(props.authToken);
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tải được danh sách cơ sở';
  } finally {
    loading.value = false;
  }
}

async function loadCourses(id: number) {
  loading.value = true;
  error.value = null;
  courses.value = [];
  emit('update:modelValue', null);
  emit('course-changed', null);
  try {
    courses.value = await courseAdminApi.listCourses(id, props.authToken);
    // One course is the common case for a Vietnamese club. Selecting it saves
    // a click that has no alternative.
    if (courses.value.length === 1) selectCourse(courses.value[0].id);
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tải được danh sách sân';
  } finally {
    loading.value = false;
  }
}

function selectCourse(id: number | null) {
  emit('update:modelValue', id);
  emit('course-changed', courses.value.find((c) => c.id === id) ?? null);
}

watch(facilityId, (id) => {
  if (id != null) loadCourses(id);
});

onMounted(loadFacilities);
</script>

<template>
  <div class="course-picker">
    <div class="picker-field">
      <label class="picker-label" for="cp-facility">Cơ sở</label>
      <select id="cp-facility" v-model="facilityId" class="picker-input" :disabled="loading">
        <option :value="null">— Chọn cơ sở —</option>
        <option v-for="f in facilities" :key="f.id" :value="f.id">{{ f.name }}</option>
      </select>
    </div>

    <div class="picker-field">
      <label class="picker-label" for="cp-course">Sân</label>
      <select
        id="cp-course"
        class="picker-input"
        :disabled="loading || courses.length === 0"
        :value="props.modelValue"
        @change="selectCourse(Number(($event.target as HTMLSelectElement).value) || null)"
      >
        <option :value="null">— Chọn sân —</option>
        <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
      </select>
    </div>

    <p v-if="error" class="picker-error" role="alert">
      {{ error }}
      <button type="button" class="picker-retry" @click="loadFacilities">Thử lại</button>
    </p>
  </div>
</template>

<style scoped>
.course-picker {
  display: flex;
  gap: 16px;
  align-items: flex-end;
  flex-wrap: wrap;
  margin-bottom: 20px;
}
.picker-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 220px;
}
.picker-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--muted);
}
.picker-input {
  padding: 8px 10px;
  border: 1px solid var(--outline-variant);
  border-radius: 6px;
  font-size: 14px;
  background: var(--surface-container-lowest);
  color: var(--on-surface);
  color-scheme: dark;
}
.picker-input option {
  background: var(--surface-container);
  color: var(--on-surface);
}
.picker-input:disabled {
  background: var(--surface-container-high);
  color: var(--muted);
}
.picker-error {
  flex-basis: 100%;
  margin: 0;
  color: var(--error);
  font-size: 13px;
}
.picker-retry {
  margin-left: 8px;
  border: 1px solid var(--error);
  background: transparent;
  color: var(--error);
  border-radius: 4px;
  padding: 2px 8px;
  cursor: pointer;
}
</style>
