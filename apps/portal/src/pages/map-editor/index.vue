<script setup lang="ts">
/**
 * Where "Biên tập bản đồ" goes.
 *
 * The sidebar item used to redirect to /facilities. Clicking "Map editor" and
 * landing on a list of golf clubs, with no word about why, is a dead end an
 * operator has to already know the shape of: the editor is per course, so you
 * are meant to drill facility → course → edit geometry. The redirect made that
 * a guess.
 *
 * So: ask the two questions the editor needs answered, and go.
 */
import { ref } from 'vue';
import { useRouter } from 'vue-router';

import CoursePicker from '@/components/CoursePicker.vue';
import type { CourseResponse } from '@/types/admin/course';

const props = defineProps<{ authToken: string }>();
const router = useRouter();

const courseId = ref<number | null>(null);
const course = ref<CourseResponse | null>(null);

function open() {
  if (courseId.value != null) {
    router.push(`/courses/${courseId.value}/edit-geometry`);
  }
}
</script>

<template>
  <div class="map-editor-landing">
    <section class="card">
      <h2 class="title">Chọn sân để biên tập</h2>
      <p class="note">
        Hình học được vẽ theo từng sân — tee, fairway, green, bunker, chướng
        ngại nước. Chọn cơ sở rồi chọn sân.
      </p>

      <CoursePicker v-model="courseId" :auth-token="props.authToken" @course-changed="course = $event" />

      <div v-if="course" class="chosen">
        <div>
          <p class="chosen-name">{{ course.name }}</p>
          <p class="chosen-meta">
            {{ course.holesCount ?? '—' }} hố
            <template v-if="course.parTotal"> · par {{ course.parTotal }}</template>
          </p>
        </div>
        <button type="button" class="btn-primary" @click="open">Mở trình biên tập →</button>
      </div>

      <p v-else class="note muted">Chưa chọn sân nào.</p>
    </section>
  </div>
</template>

<style scoped>
.map-editor-landing {
  max-width: 720px;
}
.card {
  border: 1px solid var(--outline-variant);
  border-radius: 8px;
  padding: 18px 20px;
  background: var(--surface-container-lowest);
}
.title {
  margin: 0 0 6px;
  font-size: 16px;
  font-weight: 700;
  color: var(--on-surface);
}
.note {
  margin: 0 0 14px;
  font-size: 13px;
  color: var(--muted);
}
.note.muted {
  margin: 0;
}
.chosen {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 12px 14px;
  border: 1px solid var(--outline-variant);
  border-radius: 6px;
  background: var(--surface-container);
}
.chosen-name {
  margin: 0;
  font-weight: 700;
  color: var(--on-surface);
}
.chosen-meta {
  margin: 2px 0 0;
  font-size: 12px;
  color: var(--muted);
}
.btn-primary {
  padding: 9px 18px;
  border: none;
  border-radius: 6px;
  background: var(--primary);
  color: #fff;
  font-weight: 600;
  white-space: nowrap;
  cursor: pointer;
}
</style>
