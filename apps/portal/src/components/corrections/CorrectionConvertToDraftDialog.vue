<template>
  <div class="dialog-overlay" role="dialog" aria-modal="true" aria-labelledby="convert-title">
    <div class="dialog-panel">
      <div class="dialog-header">
        <h2 id="convert-title" class="dialog-title">Chuyển thành bản nháp</h2>
        <button class="close-btn" @click="$emit('cancel')" aria-label="Đóng hộp thoại">×</button>
      </div>

      <div class="dialog-body">
        <div class="convert-notice">
          <span aria-hidden="true">📝</span>
          <p>
            Chuyển hiệu chỉnh này thành bản nháp sẽ tạo một bản nháp trong trình
            biên tập bản đồ. Bạn có thể chỉnh lại rồi publish theo quy trình biên
            tập thông thường.
          </p>
        </div>

        <div class="form-field">
          <label for="convert-note" class="field-label">
            Ghi chú <span class="optional">(không bắt buộc)</span>
          </label>
          <textarea
            id="convert-note"
            v-model="note"
            class="field-input"
            rows="3"
            placeholder="Ghi chú về việc chuyển đổi này (không bắt buộc)…"
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
          {{ loading ? 'Đang tạo…' : 'Chuyển thành bản nháp' }}
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
  (e: 'confirm', note: string): void;
  (e: 'cancel'): void;
}>();

const note = ref('');

function confirm() {
  emit('confirm', note.value.trim());
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
  background: #171f33;
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
  border-bottom: 1px solid #2d3449;
  background: #171f33;
}
.dialog-title { font-size: 1.0625rem; font-weight: 700; color: #dae2fd; margin: 0; }
.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #97a2c0;
  min-height: 44px;
  min-width: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
}
.close-btn:hover { background: #222a3d; }

.dialog-body {
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.convert-notice {
  display: flex;
  gap: 0.75rem;
  padding: 0.875rem;
  background: #222a3d;
  border: 1px solid #2d3449;
  border-radius: 6px;
  font-size: 0.875rem;
  color: #ec6a06;
  line-height: 1.5;
}
.convert-notice span:first-child { font-size: 1.25rem; flex-shrink: 0; }
.convert-notice p { margin: 0; }

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
.optional { font-weight: 400; color: #97a2c0; }
.field-input {
  /* The dialog is dark; without these three the control falls back to the
     browser default — a white box with black text, in a dark panel. */
  background: #0f1626;
  color: #dae2fd;
  color-scheme: dark;
  padding: 0.5rem 0.75rem;
  border: 1px solid #2d3449;
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
.field-hint { font-size: 0.75rem; color: #97a2c0; text-align: right; }

.dialog-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 0.875rem 1.25rem;
  border-top: 1px solid #2d3449;
  background: #171f33;
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
  background: #171f33;
  border: 1px solid #2d3449;
  color: #c5cde8;
}
.cancel-btn:hover:not(:disabled) { background: #222a3d; }

.confirm-btn {
  background: #0f766e;
  border: 1px solid #0f766e;
  color: white;
}
.confirm-btn:hover:not(:disabled) { background: #115e59; }
</style>
