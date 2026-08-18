<template>
  <div class="dialog-overlay" role="dialog" aria-modal="true" aria-labelledby="reject-title">
    <div class="dialog-panel">
      <div class="dialog-header">
        <h2 id="reject-title" class="dialog-title">Từ chối báo lỗi</h2>
        <button class="close-btn" @click="$emit('cancel')" aria-label="Đóng hộp thoại">×</button>
      </div>

      <div class="dialog-body">
        <p class="dialog-message">
          Nêu lý do từ chối hiệu chỉnh này. Lý do sẽ hiện trong nhật ký kiểm toán.
        </p>

        <div class="form-field">
          <label for="reject-reason" class="field-label">
            Lý do <span class="required" aria-hidden="true">*</span>
          </label>
          <textarea
            id="reject-reason"
            v-model="reason"
            class="field-input"
            rows="3"
            placeholder="Giải thích vì sao từ chối báo lỗi này…"
            maxlength="500"
            :aria-invalid="reasonError ? 'true' : undefined"
            :aria-describedby="reasonError ? 'reason-error' : undefined"
          ></textarea>
          <span v-if="reasonError" id="reason-error" class="field-error" role="alert">
            {{ reasonError }}
          </span>
          <span class="field-hint">{{ reason.length }}/500 ký tự</span>
        </div>

        <div class="form-field">
          <label for="reject-note" class="field-label">
            Ghi chú nội bộ <span class="optional">(không bắt buộc)</span>
          </label>
          <textarea
            id="reject-note"
            v-model="note"
            class="field-input"
            rows="2"
            placeholder="Ghi chú cho nhật ký (không bắt buộc)…"
            maxlength="500"
          ></textarea>
          <span class="field-hint">{{ note.length }}/500 ký tự</span>
        </div>
      </div>

      <div class="dialog-footer">
        <button class="action-btn cancel-btn" @click="$emit('cancel')" :disabled="loading">
          Huỷ
        </button>
        <button
          class="action-btn confirm-btn"
          :disabled="loading"
          @click="confirm"
        >
          {{ loading ? 'Đang xử lý…' : 'Từ chối hiệu chỉnh' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

defineProps<{
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'confirm', reason: string, note: string): void;
  (e: 'cancel'): void;
}>();

const reason = ref('');
const note = ref('');
const reasonError = ref<string | null>(null);

function confirm() {
  reasonError.value = null;
  if (!reason.value.trim()) {
    reasonError.value = 'Phải nêu lý do khi từ chối một hiệu chỉnh.';
    return;
  }
  emit('confirm', reason.value.trim(), note.value.trim());
}
</script>

<style scoped>
.dialog-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
  padding: 1rem;
}

.dialog-panel {
  background: var(--surface-container);
  border-radius: 12px;
  max-width: 480px;
  width: 100%;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
  overflow: hidden;
}

.dialog-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--surface-container-highest);
  background: var(--surface-container);
}
.dialog-title { font-size: 1.0625rem; font-weight: 700; color: var(--on-surface); margin: 0; }
.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--muted);
  min-height: 44px;
  min-width: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
}
.close-btn:hover { background: var(--surface-container-high); }

.dialog-body {
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.dialog-message {
  font-size: 0.875rem;
  color: #c5cde8;
  margin: 0;
  line-height: 1.5;
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}
.field-label {
  font-size: 0.875rem;
  font-weight: 600;
  color: #c5cde8;
}
.required { color: #dc2626; }
.optional { font-weight: 400; color: var(--muted); }
.field-input {
  /* The dialog is dark; without these three the control falls back to the
     browser default — a white box with black text, in a dark panel. */
  background: #0f1626;
  color: var(--on-surface);
  color-scheme: dark;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--surface-container-highest);
  border-radius: 6px;
  font-size: 0.875rem;
  font-family: inherit;
  resize: vertical;
  min-height: 80px;
  transition: border-color 0.15s;
}
.field-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}
.field-input[aria-invalid="true"] { border-color: #dc2626; }
.field-error { font-size: 0.75rem; color: #dc2626; }
.field-hint { font-size: 0.75rem; color: var(--muted); text-align: right; }

.dialog-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 0.875rem 1.25rem;
  border-top: 1px solid var(--surface-container-highest);
  background: var(--surface-container);
}

.action-btn {
  padding: 0.5rem 1.25rem;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  min-height: 44px;
  transition: background 0.15s;
}
.action-btn:disabled { opacity: 0.5; cursor: not-allowed; }

.cancel-btn {
  background: var(--surface-container);
  border: 1px solid var(--surface-container-highest);
  color: #c5cde8;
}
.cancel-btn:hover:not(:disabled) { background: var(--surface-container-high); }

.confirm-btn {
  background: #b91c1c;
  border: 1px solid #b91c1c;
  color: white;
}
.confirm-btn:hover:not(:disabled) { background: #991b1b; }
</style>
