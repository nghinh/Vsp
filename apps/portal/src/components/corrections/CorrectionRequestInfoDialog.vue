<template>
  <div class="dialog-overlay" role="dialog" aria-modal="true" aria-labelledby="request-info-title">
    <div class="dialog-panel">
      <div class="dialog-header">
        <h2 id="request-info-title" class="dialog-title">Yêu cầu bổ sung thông tin</h2>
        <button class="close-btn" @click="$emit('cancel')" aria-label="Đóng hộp thoại">×</button>
      </div>

      <div class="dialog-body">
        <p class="dialog-message">
          Gửi tin nhắn cho người báo để xin thêm thông tin. Hiệu chỉnh sẽ được
          đánh dấu "Đang chờ thông tin".
        </p>

        <div class="form-field">
          <label for="info-message" class="field-label">
            Lời nhắn cho người báo <span class="required" aria-hidden="true">*</span>
          </label>
          <textarea
            id="info-message"
            v-model="message"
            class="field-input"
            rows="4"
            placeholder="Bạn cần thêm thông tin gì để đánh giá hiệu chỉnh này?…"
            maxlength="500"
            :aria-invalid="messageError ? 'true' : undefined"
            :aria-describedby="messageError ? 'message-error' : undefined"
          ></textarea>
          <span v-if="messageError" id="message-error" class="field-error" role="alert">
            {{ messageError }}
          </span>
          <span class="field-hint">{{ message.length }}/500 ký tự</span>
        </div>

        <div class="form-field">
          <label for="info-note" class="field-label">
            Ghi chú nội bộ <span class="optional">(không bắt buộc)</span>
          </label>
          <textarea
            id="info-note"
            v-model="note"
            class="field-input"
            rows="2"
            placeholder="Ghi chú nội bộ cho nhật ký (không bắt buộc)…"
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
          {{ loading ? 'Đang gửi…' : 'Gửi yêu cầu' }}
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
  (e: 'confirm', message: string, note: string): void;
  (e: 'cancel'): void;
}>();

const message = ref('');
const note = ref('');
const messageError = ref<string | null>(null);

function confirm() {
  messageError.value = null;
  if (!message.value.trim()) {
    messageError.value = 'Phải nhập nội dung khi xin thêm thông tin.';
    return;
  }
  emit('confirm', message.value.trim(), note.value.trim());
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
  max-width: 520px;
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
  background: #7c3aed;
  border: 1px solid #7c3aed;
  color: white;
}
.confirm-btn:hover:not(:disabled) { background: #6d28d9; }
</style>
