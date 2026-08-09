<template>
  <div
    class="course-version-publish"
    role="main"
    aria-label="Công bố phiên bản sân"
  >
    <!-- Page header -->
    <header class="page-header">
      <div class="header-text">
        <h1 class="page-title">Công bố phiên bản sân</h1>
        <p class="page-subtitle" aria-label="Sân và phiên bản">
          Sân #{{ courseId }} &mdash; Phiên bản #{{ versionId }}
        </p>
      </div>
      <button
        class="back-btn"
        aria-label="Quay lại quản lý phiên bản sân"
        @click="$emit('back')"
      >
        &#8592; Quay lại
      </button>
    </header>

    <!-- Load error -->
    <div v-if="loadError" class="load-error" role="alert">
      <span class="error-icon" aria-hidden="true">&#9888;</span>
      <div class="error-content">
        <strong>Không tải được dữ liệu</strong>
        <span>{{ loadError }}</span>
      </div>
      <button class="retry-btn" @click="loadAll">Thử lại</button>
    </div>

    <div v-else class="publish-layout">

      <!-- Left column: Validation + Diff -->
      <div class="left-column">

        <!-- Validation section -->
        <section class="publish-section" aria-labelledby="validation-heading">
          <div class="section-header">
            <h2 id="validation-heading" class="section-title">Kiểm tra trước khi công bố</h2>
            <button
              class="validate-btn"
              :class="{ loading: validating }"
              :disabled="validating || publishing"
              aria-label="Chạy kiểm tra"
              @click="handleValidate"
            >
              <span v-if="validating" class="btn-spinner" aria-hidden="true"></span>
              <span v-else aria-hidden="true">&#10004;</span>
              {{ validating ? 'Đang kiểm tra…' : 'Kiểm tra' }}
            </button>
          </div>

          <!-- Initial idle state -->
          <div v-if="!validationResult && !validating" class="idle-state" role="status">
            <span class="idle-icon" aria-hidden="true">&#128269;</span>
            <span>Chạy kiểm tra hình học, siêu dữ liệu, nguồn, giấy phép và chất lượng dữ liệu.</span>
          </div>

          <!-- Validation loading -->
          <div v-if="validating" class="loading-state" aria-busy="true" aria-label="Đang kiểm tra">
            <div class="loading-spinner" aria-hidden="true"></div>
            <span>Đang kiểm tra trước khi publish…</span>
          </div>

          <!-- Validation result -->
          <ValidationResult
            v-if="validationResult && !validating"
            :validation="validationResult"
          />

          <!-- Validation error -->
          <div v-if="validationError && !validating" class="api-error" role="alert">
            <span class="error-icon" aria-hidden="true">&#9888;</span>
            <span>{{ validationError }}</span>
            <button class="inline-retry-btn" @click="handleValidate">Thử lại</button>
          </div>
        </section>

        <!-- Diff section -->
        <section class="publish-section" aria-labelledby="diff-heading">
          <div class="section-header">
            <h2 id="diff-heading" class="section-title">Thay đổi so với lần công bố trước</h2>
            <button
              class="reload-diff-btn"
              :disabled="diffLoading || publishing"
              aria-label="Tải lại so sánh"
              @click="loadDiff"
            >
              {{ diffLoading ? 'Đang tải…' : 'Tải lại' }}
            </button>
          </div>

          <div v-if="diffLoading" class="loading-state" aria-busy="true" aria-label="Đang tải so sánh">
            <div class="loading-spinner" aria-hidden="true"></div>
            <span>Đang tải khác biệt phiên bản…</span>
          </div>

          <VersionDiff v-if="diffResult && !diffLoading" :diff="diffResult" />

          <div v-if="diffError && !diffLoading" class="api-error" role="alert">
            <span class="error-icon" aria-hidden="true">&#9888;</span>
            <span>{{ diffError }}</span>
            <button class="inline-retry-btn" @click="loadDiff">Thử lại</button>
          </div>

          <div v-if="!diffResult && !diffLoading && !diffError" class="idle-state" role="status">
            <span class="idle-icon" aria-hidden="true">&#8801;</span>
            <span>Bảng so sánh hiện sau khi chạy kiểm tra.</span>
          </div>
        </section>
      </div>

      <!-- Right column: Publish form -->
      <div class="right-column">

        <!-- Publish form card -->
        <div class="publish-card" :class="{ 'publish-card--blocked': !canPublish }">

          <div class="card-header">
            <h2 class="card-title">Công bố phiên bản</h2>
          </div>

          <!-- Blocking banner -->
          <div v-if="!canPublish" class="blocking-banner" role="alert">
            <span class="blocking-icon" aria-hidden="true">&#9888;</span>
            <span>Sửa hết lỗi chặn ở trên rồi mới công bố.</span>
          </div>

          <div class="card-body">
            <!-- Publish note -->
            <PublishNote
              v-model="publishForm"
              :disabled="publishing"
            />

            <!-- Publish button -->
            <button
              class="publish-btn"
              :class="{ loading: publishing }"
              :disabled="!canPublish || !publishNoteValid || publishing"
              :aria-disabled="!canPublish || !publishNoteValid || publishing"
              @click="showConfirmDialog = true"
            >
              <span v-if="publishing" class="btn-spinner" aria-hidden="true"></span>
              <span v-if="publishing">Đang publish…</span>
              <span v-else>
                <span aria-hidden="true">&#128640;</span>
                Công bố phiên bản
              </span>
            </button>

            <!-- Publish error -->
            <div v-if="publishError" class="publish-error" role="alert">
              <span class="error-icon" aria-hidden="true">&#10060;</span>
              <div class="publish-error-content">
                <strong>Công bố thất bại</strong>
                <span>{{ publishError }}</span>
              </div>
              <button class="inline-retry-btn" @click="handlePublish">Thử lại</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Confirmation dialog -->
    <div
      v-if="showConfirmDialog"
      class="dialog-backdrop"
      role="dialog"
      aria-modal="true"
      aria-labelledby="confirm-dialog-title"
      @click.self="showConfirmDialog = false"
      @keydown.escape="showConfirmDialog = false"
    >
      <div class="dialog-panel" role="document">
        <h2 id="confirm-dialog-title" class="dialog-title">Xác nhận công bố</h2>
        <div class="dialog-body">
          <p class="dialog-message">
            Bạn sắp công bố phiên bản <strong>#{{ versionId }}</strong> của sân <strong>#{{ courseId }}</strong>.
          </p>
          <p class="dialog-message dialog-message--warning">
            Phiên bản sẽ được khoá lại và mở cho ứng dụng di động. Một tác vụ đóng gói sẽ tự động được xếp hàng.
          </p>
          <div class="dialog-note-preview" v-if="publishForm.note">
            <span class="dialog-note-label">Ghi chú công bố của bạn:</span>
            <blockquote class="dialog-note-text">{{ publishForm.note }}</blockquote>
          </div>
        </div>
        <div class="dialog-actions">
          <button
            class="dialog-cancel-btn"
            :disabled="publishing"
            @click="showConfirmDialog = false"
          >
            Huỷ
          </button>
          <button
            class="dialog-confirm-btn"
            :class="{ loading: publishing }"
            :disabled="publishing"
            @click="confirmPublish"
          >
            <span v-if="publishing" class="btn-spinner btn-spinner--dark" aria-hidden="true"></span>
            {{ publishing ? 'Đang publish…' : 'Xác nhận publish' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Success overlay -->
    <div
      v-if="publishSuccess"
      class="success-overlay"
      role="status"
      aria-live="polite"
    >
      <div class="success-panel">
        <span class="success-icon" aria-hidden="true">&#127881;</span>
        <h2 class="success-title">Đã publish phiên bản!</h2>
        <p class="success-message">
          Phiên bản <strong>#{{ publishSuccess.newVersionId }}</strong> đã lên sóng.
        </p>
        <div class="success-meta">
          <span>Mã audit: <code class="meta-code">{{ publishSuccess.auditId }}</code></span>
          <span v-if="publishSuccess.buildJobId">
            Tác vụ đóng gói: <code class="meta-code">{{ publishSuccess.buildJobId }}</code>
          </span>
          <!--
            A null build job means the version was published and no package will
            be built from it — so the course will advertise a download with
            nothing behind it. The server logs it; this is the only place an
            operator would ever find out.
          -->
          <span v-else class="build-missing" role="alert">
            Đã phát hành, nhưng chưa xếp được hàng đợi tạo gói offline. Sân này
            sẽ chưa tải về được — hãy báo kỹ thuật.
          </span>
        </div>
        <button class="success-btn" @click="$emit('published', publishSuccess)">
          Xem chi tiết phiên bản
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import ValidationResult from './ValidationResult.vue';
import VersionDiff from './VersionDiff.vue';
import PublishNote from './PublishNote.vue';
import { courseVersionPublishApi, OfflineError } from '@/api/course-version-publish';
import type {
  ValidationResponse,
  VersionDiff as VersionDiffType,
  PublishResponse,
  PublishApiError,
} from '@/types/course-version-publish';

const MIN_NOTE_LENGTH = 10;

const props = defineProps<{
  courseId: number;
  versionId: number;
  authToken: string;
}>();

defineEmits<{
  (e: 'back'): void;
  (e: 'published', response: PublishResponse): void;
}>();

// ─── State ────────────────────────────────────────────────────────────────────

const validating = ref(false);
const validationResult = ref<ValidationResponse | null>(null);
const validationError = ref<string | null>(null);

const diffLoading = ref(false);
const diffResult = ref<VersionDiffType | null>(null);
const diffError = ref<string | null>(null);

const publishing = ref(false);
const publishError = ref<string | null>(null);
const publishSuccess = ref<PublishResponse | null>(null);

const loadError = ref<string | null>(null);

const publishForm = ref({ note: '', forcePublish: false });
const showConfirmDialog = ref(false);

// ─── Computed ─────────────────────────────────────────────────────────────────

const hasBlockingErrors = computed(() =>
  validationResult.value != null &&
  validationResult.value.errors.length > 0
);

const canPublish = computed(() =>
  validationResult.value !== null &&
  !hasBlockingErrors.value
);

const publishNoteValid = computed(() =>
  publishForm.value.note.trim().length >= MIN_NOTE_LENGTH
);

// ─── Actions ──────────────────────────────────────────────────────────────────

async function loadAll() {
  loadError.value = null;
  await Promise.all([handleValidate(), loadDiff()]);
}

async function handleValidate() {
  validating.value = true;
  validationError.value = null;
  try {
    validationResult.value = await courseVersionPublishApi.validate(
      props.courseId,
      props.versionId,
      props.authToken
    );
    // Also load diff after validation (needed for audit trail)
    if (!diffResult.value) {
      await loadDiff();
    }
  } catch (err) {
    if (err instanceof OfflineError) {
      validationError.value = err.message;
    } else {
      const apiErr = err as PublishApiError;
      validationError.value = apiErr?.message ?? 'Kiểm tra thất bại. Hãy thử lại.';
    }
  } finally {
    validating.value = false;
  }
}

async function loadDiff() {
  diffLoading.value = true;
  diffError.value = null;
  try {
    diffResult.value = await courseVersionPublishApi.getDiff(
      props.courseId,
      props.versionId,
      props.authToken
    );
  } catch (err) {
    if (err instanceof OfflineError) {
      diffError.value = err.message;
    } else {
      const apiErr = err as PublishApiError;
      diffError.value = apiErr?.message ?? 'Không tải được khác biệt phiên bản. Hãy thử lại.';
    }
  } finally {
    diffLoading.value = false;
  }
}

async function handlePublish() {
  if (!canPublish.value || !publishNoteValid.value) return;
  await doPublish();
}

async function confirmPublish() {
  showConfirmDialog.value = false;
  await doPublish();
}

async function doPublish() {
  publishing.value = true;
  publishError.value = null;
  try {
    publishSuccess.value = await courseVersionPublishApi.publish(
      props.courseId,
      props.versionId,
      {
        publishNote: publishForm.value.note.trim(),
        forcePublish: publishForm.value.forcePublish,
      },
      props.authToken
    );
  } catch (err) {
    if (err instanceof OfflineError) {
      publishError.value = err.message;
    } else {
      const apiErr = err as PublishApiError;
      if (apiErr?.code === 'VALIDATION_FAILED') {
        publishError.value = 'Vẫn còn lỗi chặn publish. Hãy sửa hết trước khi publish.';
      } else if (apiErr?.code === 'PUBLISH_FORBIDDEN') {
        publishError.value = 'Phiên bản này đã publish hoặc không ở trạng thái DRAFT.';
      } else {
        publishError.value = apiErr?.message ?? 'Publish thất bại. Hãy thử lại.';
      }
    }
  } finally {
    publishing.value = false;
  }
}

// ─── Lifecycle ───────────────────────────────────────────────────────────────

onMounted(() => {
  loadAll();
});
</script>

<style scoped>
.course-version-publish {
  font-family: var(--vsp-font-body, system-ui, -apple-system, sans-serif);
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-6, 24px);
  padding: var(--vsp-space-6, 24px);
  max-width: 1200px;
  margin: 0 auto;
  box-sizing: border-box;
}

/* Page header */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: var(--vsp-space-4, 16px);
  padding-bottom: var(--vsp-space-4, 16px);
  border-bottom: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
}

.page-title {
  font-size: var(--vsp-font-size-2xl, 1.5rem);
  font-weight: var(--vsp-font-weight-bold, 700);
  color: var(--vsp-color-text-primary, #0F172A);
  margin: 0;
}

.page-subtitle {
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-text-secondary, #475569);
  margin: var(--vsp-space-1, 4px) 0 0;
  font-family: var(--vsp-font-mono, monospace);
}

.back-btn {
  display: inline-flex;
  align-items: center;
  gap: var(--vsp-space-1, 4px);
  padding: var(--vsp-space-2, 8px) var(--vsp-space-4, 16px);
  border-radius: var(--vsp-radius-md, 8px);
  border: 1px solid var(--vsp-color-border-strong, rgba(15, 23, 42, 0.16));
  background: transparent;
  color: var(--vsp-color-text-primary, #0F172A);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-medium, 500);
  cursor: pointer;
  min-height: var(--vsp-touch-target-min, 44px);
  font-family: inherit;
  transition: background var(--vsp-duration-press, 80ms) ease;
}

.back-btn:hover {
  background: var(--vsp-color-muted, #F8FAFC);
}

.back-btn:focus-visible {
  outline: none;
  box-shadow: var(--vsp-focus-ring, 0 0 0 2px var(--vsp-color-ring, #EA580C));
}

/* Layout */
.publish-layout {
  display: grid;
  grid-template-columns: 1fr 380px;
  gap: var(--vsp-space-6, 24px);
  align-items: start;
}

@media (max-width: 900px) {
  .publish-layout {
    grid-template-columns: 1fr;
  }
}

.left-column,
.right-column {
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-4, 16px);
}

/* Sections */
.publish-section {
  background: var(--vsp-color-surface, #fff);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  border-radius: var(--vsp-radius-lg, 12px);
  overflow: hidden;
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--vsp-space-4, 16px);
  border-bottom: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  background: var(--vsp-color-muted, #F8FAFC);
  flex-wrap: wrap;
  gap: var(--vsp-space-2, 8px);
}

.section-title {
  font-size: var(--vsp-font-size-base, 1rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  color: var(--vsp-color-text-primary, #0F172A);
  margin: 0;
}

.validate-btn,
.reload-diff-btn {
  display: inline-flex;
  align-items: center;
  gap: var(--vsp-space-1-5, 6px);
  padding: var(--vsp-space-2, 8px) var(--vsp-space-4, 16px);
  border-radius: var(--vsp-radius-md, 8px);
  border: 1px solid var(--vsp-color-primary, #EA580C);
  background: var(--vsp-color-primary, #EA580C);
  color: var(--vsp-color-on-primary, #fff);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  cursor: pointer;
  min-height: var(--vsp-touch-target-min, 44px);
  font-family: inherit;
  transition: background var(--vsp-duration-press, 80ms) ease;
}

.validate-btn:hover:not(:disabled),
.reload-diff-btn:hover:not(:disabled) {
  background: color-mix(in srgb, var(--vsp-color-primary, #EA580C) 88%, black);
}

.validate-btn:disabled,
.reload-diff-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.validate-btn:focus-visible,
.reload-diff-btn:focus-visible {
  outline: none;
  box-shadow: var(--vsp-focus-ring, 0 0 0 2px var(--vsp-color-ring, #EA580C));
}

.reload-diff-btn {
  background: transparent;
  color: var(--vsp-color-primary, #EA580C);
}

.reload-diff-btn:hover:not(:disabled) {
  background: color-mix(in srgb, var(--vsp-color-primary, #EA580C) 10%, transparent);
}

/* Idle / loading states */
.idle-state,
.loading-state {
  display: flex;
  align-items: center;
  gap: var(--vsp-space-2, 8px);
  padding: var(--vsp-space-4, 16px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-text-secondary, #475569);
}

.idle-icon { font-size: 1.25rem; }

.loading-spinner {
  width: 20px;
  height: 20px;
  border: 2px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  border-top-color: var(--vsp-color-primary, #EA580C);
  border-radius: var(--vsp-radius-full, 9999px);
  animation: spin 0.6s linear infinite;
  flex-shrink: 0;
}

@keyframes spin { to { transform: rotate(360deg); } }

/* Error */
.api-error,
.load-error {
  display: flex;
  align-items: flex-start;
  gap: var(--vsp-space-2, 8px);
  padding: var(--vsp-space-3, 12px) var(--vsp-space-4, 16px);
  background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 6%, transparent);
  border-top: 1px solid color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 20%, transparent);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-destructive, #DC2626);
}

.load-error {
  padding: var(--vsp-space-4, 16px);
  border-radius: var(--vsp-radius-md, 8px);
  border: 1px solid color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 20%, transparent);
}

.error-icon { font-size: 1.1rem; flex-shrink: 0; }

.error-content {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.inline-retry-btn {
  margin-left: auto;
  padding: var(--vsp-space-1, 4px) var(--vsp-space-3, 12px);
  border-radius: var(--vsp-radius-sm, 4px);
  border: 1px solid var(--vsp-color-destructive, #DC2626);
  background: transparent;
  color: var(--vsp-color-destructive, #DC2626);
  font-size: var(--vsp-font-size-xs, 0.75rem);
  font-weight: var(--vsp-font-weight-medium, 500);
  cursor: pointer;
  min-height: 32px;
  font-family: inherit;
}

.inline-retry-btn:hover { background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 10%, transparent); }

.retry-btn {
  padding: var(--vsp-space-2, 8px) var(--vsp-space-4, 16px);
  border-radius: var(--vsp-radius-md, 8px);
  border: 1px solid var(--vsp-color-destructive, #DC2626);
  background: var(--vsp-color-destructive, #DC2626);
  color: var(--vsp-color-on-destructive, #fff);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  cursor: pointer;
  min-height: var(--vsp-touch-target-min, 44px);
  font-family: inherit;
  flex-shrink: 0;
}

.retry-btn:hover { background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 88%, black); }

/* Publish card */
.publish-card {
  background: var(--vsp-color-surface, #fff);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  border-radius: var(--vsp-radius-lg, 12px);
  overflow: hidden;
  position: sticky;
  top: var(--vsp-space-4, 16px);
  box-shadow: var(--vsp-shadow-card, 0 1px 2px rgba(0, 0, 0, 0.04), 0 1px 3px rgba(0, 0, 0, 0.08));
}

.publish-card--blocked {
  opacity: 0.7;
}

.card-header {
  padding: var(--vsp-space-4, 16px);
  border-bottom: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  background: var(--vsp-color-muted, #F8FAFC);
}

.card-title {
  font-size: var(--vsp-font-size-base, 1rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  color: var(--vsp-color-text-primary, #0F172A);
  margin: 0;
}

.blocking-banner {
  display: flex;
  align-items: center;
  gap: var(--vsp-space-2, 8px);
  padding: var(--vsp-space-3, 12px) var(--vsp-space-4, 16px);
  background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 8%, transparent);
  border-bottom: 1px solid color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 20%, transparent);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-medium, 500);
  color: var(--vsp-color-destructive, #DC2626);
}

.blocking-icon { font-size: 1rem; flex-shrink: 0; }

.card-body {
  padding: var(--vsp-space-4, 16px);
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-4, 16px);
}

/* Publish button */
.publish-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--vsp-space-2, 8px);
  width: 100%;
  padding: var(--vsp-space-3, 12px) var(--vsp-space-4, 16px);
  border-radius: var(--vsp-radius-md, 8px);
  border: 1px solid var(--vsp-color-primary, #EA580C);
  background: var(--vsp-color-primary, #EA580C);
  color: var(--vsp-color-on-primary, #fff);
  font-size: var(--vsp-font-size-base, 1rem);
  font-weight: var(--vsp-font-weight-bold, 700);
  cursor: pointer;
  min-height: var(--vsp-touch-target-min, 44px);
  font-family: inherit;
  transition: background var(--vsp-duration-press, 80ms) ease;
}

.publish-btn:hover:not(:disabled) {
  background: color-mix(in srgb, var(--vsp-color-primary, #EA580C) 88%, black);
}

.publish-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.publish-btn:focus-visible {
  outline: none;
  box-shadow: var(--vsp-focus-ring, 0 0 0 2px var(--vsp-color-ring, #EA580C));
}

.publish-error {
  display: flex;
  align-items: flex-start;
  gap: var(--vsp-space-2, 8px);
  padding: var(--vsp-space-3, 12px);
  background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 6%, transparent);
  border: 1px solid color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 20%, transparent);
  border-radius: var(--vsp-radius-md, 8px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-destructive, #DC2626);
}

.publish-error-content {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
}

.btn-spinner {
  display: inline-block;
  width: 1em;
  height: 1em;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: var(--vsp-radius-full, 9999px);
  animation: spin 0.6s linear infinite;
  flex-shrink: 0;
}

.btn-spinner--dark {
  border-color: rgba(255, 255, 255, 0.4);
  border-right-color: transparent;
}

/* Confirmation dialog */
.dialog-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.48);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
  padding: var(--vsp-space-4, 16px);
}

.dialog-panel {
  background: var(--vsp-color-surface, #fff);
  border-radius: var(--vsp-radius-xl, 16px);
  padding: var(--vsp-space-6, 24px);
  max-width: 480px;
  width: 100%;
  box-shadow: var(--vsp-shadow-modal, 0 8px 16px rgba(0, 0, 0, 0.10), 0 8px 24px rgba(0, 0, 0, 0.14));
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-4, 16px);
}

.dialog-title {
  font-size: var(--vsp-font-size-xl, 1.25rem);
  font-weight: var(--vsp-font-weight-bold, 700);
  color: var(--vsp-color-text-primary, #0F172A);
  margin: 0;
}

.dialog-body {
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-3, 12px);
}

.dialog-message {
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-text-secondary, #475569);
  margin: 0;
  line-height: var(--vsp-line-height-relaxed, 1.625);
}

.dialog-message--warning {
  color: var(--vsp-color-secondary, #F97316);
  font-weight: var(--vsp-font-weight-medium, 500);
}

.dialog-note-preview {
  background: var(--vsp-color-muted, #F8FAFC);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  border-radius: var(--vsp-radius-md, 8px);
  padding: var(--vsp-space-3, 12px);
}

.dialog-note-label {
  font-size: var(--vsp-font-size-xs, 0.75rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  color: var(--vsp-color-text-secondary, #475569);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  display: block;
  margin-bottom: var(--vsp-space-1, 4px);
}

.dialog-note-text {
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-text-primary, #0F172A);
  margin: 0;
  font-style: italic;
  border-left: 3px solid var(--vsp-color-primary, #EA580C);
  padding-left: var(--vsp-space-2, 8px);
}

.dialog-actions {
  display: flex;
  gap: var(--vsp-space-3, 12px);
  justify-content: flex-end;
  flex-wrap: wrap;
}

.dialog-cancel-btn,
.dialog-confirm-btn {
  padding: var(--vsp-space-2, 8px) var(--vsp-space-6, 24px);
  border-radius: var(--vsp-radius-md, 8px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  cursor: pointer;
  min-height: var(--vsp-touch-target-min, 44px);
  font-family: inherit;
  transition: background var(--vsp-duration-press, 80ms) ease;
}

.dialog-cancel-btn {
  background: transparent;
  border: 1px solid var(--vsp-color-border-strong, rgba(15, 23, 42, 0.16));
  color: var(--vsp-color-text-primary, #0F172A);
}

.dialog-cancel-btn:hover { background: var(--vsp-color-muted, #F8FAFC); }

.dialog-confirm-btn {
  background: var(--vsp-color-primary, #EA580C);
  border: 1px solid var(--vsp-color-primary, #EA580C);
  color: var(--vsp-color-on-primary, #fff);
  display: flex;
  align-items: center;
  gap: var(--vsp-space-2, 8px);
}

.dialog-confirm-btn:hover:not(:disabled) {
  background: color-mix(in srgb, var(--vsp-color-primary, #EA580C) 88%, black);
}

.dialog-confirm-btn:disabled { opacity: 0.5; cursor: not-allowed; }

.dialog-cancel-btn:focus-visible,
.dialog-confirm-btn:focus-visible {
  outline: none;
  box-shadow: var(--vsp-focus-ring, 0 0 0 2px var(--vsp-color-ring, #EA580C));
}

/* Success overlay */
.success-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.48);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 200;
  padding: var(--vsp-space-4, 16px);
}

.success-panel {
  background: var(--vsp-color-surface, #fff);
  border-radius: var(--vsp-radius-xl, 16px);
  padding: var(--vsp-space-8, 32px);
  max-width: 420px;
  width: 100%;
  text-align: center;
  box-shadow: var(--vsp-shadow-modal, 0 8px 16px rgba(0, 0, 0, 0.10), 0 8px 24px rgba(0, 0, 0, 0.14));
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--vsp-space-4, 16px);
}

.success-icon { font-size: 3rem; }

.success-title {
  font-size: var(--vsp-font-size-2xl, 1.5rem);
  font-weight: var(--vsp-font-weight-bold, 700);
  color: var(--vsp-color-official, #059669);
  margin: 0;
}

.success-message {
  font-size: var(--vsp-font-size-base, 1rem);
  color: var(--vsp-color-text-secondary, #475569);
  margin: 0;
}

.success-meta {
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-1, 4px);
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
}

.meta-code {
  font-family: var(--vsp-font-mono, monospace);
  background: var(--vsp-color-muted, #F8FAFC);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  border-radius: var(--vsp-radius-sm, 4px);
  padding: 1px var(--vsp-space-1, 4px);
}

.success-btn {
  padding: var(--vsp-space-3, 12px) var(--vsp-space-6, 24px);
  border-radius: var(--vsp-radius-md, 8px);
  border: 1px solid var(--vsp-color-official, #059669);
  background: var(--vsp-color-official, #059669);
  color: var(--vsp-color-on-accent, #fff);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  cursor: pointer;
  min-height: var(--vsp-touch-target-min, 44px);
  font-family: inherit;
}

.success-btn:hover { background: color-mix(in srgb, var(--vsp-color-official, #059669) 88%, black); }

.success-btn:focus-visible {
  outline: none;
  box-shadow: var(--vsp-focus-ring, 0 0 0 2px var(--vsp-color-ring, #EA580C));
}
</style>
