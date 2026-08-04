<template>
  <div class="publish-page">
    <CourseVersionPublish
      v-if="courseId && versionId"
      :course-id="courseId"
      :version-id="versionId"
      :auth-token="authToken"
      @back="handleBack"
      @published="handlePublished"
    />
    <div v-else class="missing-params" role="alert">
      Missing courseId or versionId in URL.
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import CourseVersionPublish from '@/components/course-version-publish/CourseVersionPublish.vue';
import type { PublishResponse } from '@/types/course-version-publish';

const route = useRoute();
const router = useRouter();

// Auth token — injected by portal shell (stubbed here for type safety)
const authToken = computed<string>(() =>
  (route.query.authToken as string) ?? ''
);

const courseId = computed<number>(() => {
  const id = route.params.courseId;
  return typeof id === 'string' ? parseInt(id, 10) : NaN;
});

const versionId = computed<number>(() => {
  const id = route.params.versionId;
  return typeof id === 'string' ? parseInt(id, 10) : NaN;
});

function handleBack() {
  // Navigate back to the course version management screen
  router.push(`/courses/${courseId.value}/versions`);
}

function handlePublished(response: PublishResponse) {
  // Navigate to the version detail / audit screen after successful publish
  router.push(`/courses/${courseId.value}/versions/${response.newVersionId}`);
}
</script>

<style scoped>
.publish-page {
  min-height: 100vh;
  background: var(--vsp-color-background, #fff);
}

.missing-params {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  font-family: var(--vsp-font-body, system-ui, sans-serif);
  font-size: var(--vsp-font-size-base, 1rem);
  color: var(--vsp-color-destructive, #DC2626);
}
</style>
