<template>
  <div
    class="validation-result"
    role="region"
    aria-label="Kết quả kiểm tra"
    :aria-live="hasBlockingErrors ? 'assertive' : 'polite'"
  >
    <!-- Result badge -->
    <div class="result-header">
      <span
        class="result-badge"
        :class="badgeClass"
        role="status"
        :aria-label="`Validation result: ${resultLabel}`"
      >
        <span class="badge-icon" aria-hidden="true">{{ resultIcon }}</span>
        <span class="badge-text">{{ resultLabel }}</span>
      </span>
      <span class="version-ref" aria-label="Mã phiên bản">v{{ versionId }}</span>
    </div>

    <!-- Blocking errors -->
    <div v-if="hasBlockingErrors" class="errors-section" role="alert" aria-label="Lỗi chặn">
      <h3 class="section-heading error-heading">
        <span aria-hidden="true">&#10060;</span>
        Lỗi — không thể publish
      </h3>
      <ul class="error-list" role="list">
        <li
          v-for="(err, idx) in errors"
          :key="`err-${idx}`"
          class="error-item"
        >
          <div class="error-main">
            <span class="entity-badge" aria-label="Loại đối tượng">{{ err.entity }}</span>
            <span class="error-message" aria-label="Thông báo lỗi">{{ err.message }}</span>
          </div>
          <div class="error-meta">
            <span class="field-ref" aria-label="Trường">Trường: {{ err.field }}</span>
            <span v-if="err.entityId" class="entity-id-ref" aria-label="Mã đối tượng">#{{ err.entityId }}</span>
            <span class="error-code" aria-label="Mã lỗi">{{ err.code }}</span>
          </div>
        </li>
      </ul>
    </div>

    <!-- Non-blocking warnings -->
    <div v-if="hasWarnings" class="warnings-section" aria-label="Cảnh báo">
      <h3 class="section-heading warning-heading">
        <span aria-hidden="true">&#9888;</span>
        Cảnh báo
      </h3>
      <ul class="warning-list" role="list">
        <li
          v-for="(warn, idx) in warnings"
          :key="`warn-${idx}`"
          class="warning-item"
        >
          <div class="warning-main">
            <span class="entity-badge" aria-label="Loại đối tượng">{{ warn.entity }}</span>
            <span class="warning-message" aria-label="Nội dung cảnh báo">{{ warn.message }}</span>
          </div>
          <div class="warning-meta">
            <span class="field-ref" aria-label="Trường">Trường: {{ warn.field }}</span>
            <span v-if="warn.entityId" class="entity-id-ref" aria-label="Mã đối tượng">#{{ warn.entityId }}</span>
          </div>
        </li>
      </ul>
    </div>

    <!-- Valid state -->
    <div v-if="isValid && !hasWarnings" class="valid-state" role="status">
      <span aria-hidden="true">&#9989;</span>
      <span>Không có lỗi. Sẵn sàng công bố.</span>
    </div>

    <!-- Valid with warnings -->
    <div v-if="isValid && hasWarnings" class="valid-with-warnings" role="status">
      <span aria-hidden="true">&#9989;</span>
      <span>Không có lỗi chặn. Xem lại cảnh báo trước khi công bố.</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ValidationResponse, ValidationResultCode } from '@/types/course-version-publish';

const props = defineProps<{
  validation: ValidationResponse;
}>();

const versionId = computed(() => props.validation.versionId);
const result = computed(() => props.validation.result);
const errors = computed(() => props.validation.errors ?? []);
const warnings = computed(() => props.validation.warnings ?? []);

const hasBlockingErrors = computed(() => errors.value.length > 0);
const hasWarnings = computed(() => warnings.value.length > 0);
const isValid = computed(() => result.value === 'VALID');

const resultLabel = computed(() => {
  const labels: Record<ValidationResultCode, string> = {
    VALID: 'Hợp lệ',
    GEOMETRY_INVALID: 'Hình học không hợp lệ',
    METADATA_MISSING: 'Thiếu siêu dữ liệu',
    LICENSE_MISSING: 'Thiếu giấy phép',
    QUALITY_INSUFFICIENT: 'Chất lượng chưa đạt',
    SOURCE_MISSING: 'Thiếu nguồn',
    VALIDATION_ERROR: 'Lỗi kiểm tra',
  };
  return labels[result.value] ?? 'Không rõ';
});

const badgeClass = computed(() => {
  if (hasBlockingErrors.value) return 'badge-error';
  if (isValid.value && hasWarnings.value) return 'badge-warning';
  if (isValid.value) return 'badge-success';
  return 'badge-unknown';
});

const resultIcon = computed(() => {
  if (hasBlockingErrors.value) return '&#10060;';
  if (isValid.value) return '&#9989;';
  return '&#9888;';
});
</script>

<style scoped>
.validation-result {
  font-family: var(--vsp-font-body, system-ui, -apple-system, sans-serif);
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-3, 12px);
  padding: var(--vsp-space-4, 16px);
  border-radius: var(--vsp-radius-md, 8px);
  background: var(--vsp-color-surface, #fff);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
}

/* Result header */
.result-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: var(--vsp-space-2, 8px);
}

.result-badge {
  display: inline-flex;
  align-items: center;
  gap: var(--vsp-space-1-5, 6px);
  padding: var(--vsp-space-1, 4px) var(--vsp-space-3, 12px);
  border-radius: var(--vsp-radius-full, 9999px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  border: 1px solid currentColor;
}

.badge-success {
  color: var(--vsp-color-official, #059669);
  background: color-mix(in srgb, var(--vsp-color-official, #059669) 12%, transparent);
}
.badge-error {
  color: var(--vsp-color-destructive, #DC2626);
  background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 12%, transparent);
}
.badge-warning {
  color: var(--vsp-color-secondary, #F97316);
  background: color-mix(in srgb, var(--vsp-color-secondary, #F97316) 12%, transparent);
}
.badge-unknown {
  color: var(--vsp-color-text-secondary, #475569);
  background: var(--vsp-color-muted, #F8FAFC);
}

.badge-icon { font-size: 1rem; }

.version-ref {
  font-family: var(--vsp-font-mono, monospace);
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
}

/* Section headings */
.section-heading {
  display: flex;
  align-items: center;
  gap: var(--vsp-space-1-5, 6px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  margin: 0 0 var(--vsp-space-2, 8px) 0;
  padding-bottom: var(--vsp-space-1, 4px);
  border-bottom: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
}
.error-heading { color: var(--vsp-color-destructive, #DC2626); }
.warning-heading { color: var(--vsp-color-secondary, #F97316); }

/* Error / warning lists */
.error-list,
.warning-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-2, 8px);
}

.error-item,
.warning-item {
  padding: var(--vsp-space-2, 8px);
  border-radius: var(--vsp-radius-sm, 4px);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-1, 4px);
}

.error-item {
  background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 6%, transparent);
  border-color: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 20%, transparent);
}

.warning-item {
  background: color-mix(in srgb, var(--vsp-color-secondary, #F97316) 6%, transparent);
  border-color: color-mix(in srgb, var(--vsp-color-secondary, #F97316) 20%, transparent);
}

.error-main,
.warning-main {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: var(--vsp-space-2, 8px);
}

.entity-badge {
  font-size: var(--vsp-font-size-xs, 0.75rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  background: var(--vsp-color-muted, #F8FAFC);
  border: 1px solid var(--vsp-color-border-strong, rgba(15, 23, 42, 0.16));
  border-radius: var(--vsp-radius-sm, 4px);
  padding: 1px var(--vsp-space-1, 4px);
  white-space: nowrap;
}

.error-message {
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-text-primary, #0F172A);
  font-weight: var(--vsp-font-weight-medium, 500);
}

.warning-message {
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-text-secondary, #475569);
}

.error-meta,
.warning-meta {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: var(--vsp-space-2, 8px);
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
}

.field-ref { font-family: var(--vsp-font-mono, monospace); }
.entity-id-ref { font-family: var(--vsp-font-mono, monospace); }

.error-code {
  font-family: var(--vsp-font-mono, monospace);
  background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 30%, transparent);
  border-radius: var(--vsp-radius-sm, 4px);
  padding: 1px var(--vsp-space-1, 4px);
  color: var(--vsp-color-destructive, #DC2626);
}

/* Valid states */
.valid-state,
.valid-with-warnings {
  display: flex;
  align-items: center;
  gap: var(--vsp-space-2, 8px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-official, #059669);
  padding: var(--vsp-space-2, 8px);
  border-radius: var(--vsp-radius-sm, 4px);
  background: color-mix(in srgb, var(--vsp-color-official, #059669) 8%, transparent);
  border: 1px solid color-mix(in srgb, var(--vsp-color-official, #059669) 20%, transparent);
}

.valid-with-warnings {
  color: var(--vsp-color-secondary, #F97316);
  background: color-mix(in srgb, var(--vsp-color-secondary, #F97316) 8%, transparent);
  border-color: color-mix(in srgb, var(--vsp-color-secondary, #F97316) 20%, transparent);
}
</style>
