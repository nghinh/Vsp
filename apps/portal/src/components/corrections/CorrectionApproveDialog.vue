<template>
  <div class="dialog-overlay" role="dialog" aria-modal="true" :aria-labelledby="titleId">
    <div class="dialog-panel">
      <div class="dialog-header">
        <h2 :id="titleId" class="dialog-title">{{ title }}</h2>
        <button class="close-btn" @click="$emit('cancel')" aria-label="Đóng hộp thoại">×</button>
      </div>

      <div class="dialog-body">
        <p class="dialog-message">{{ message }}</p>

        <div class="form-field">
          <label :for="noteId" class="field-label">
            Ghi chú <span class="optional">(không bắt buộc)</span>
          </label>
          <textarea
            :id="noteId"
            v-model="note"
            class="field-input"
            rows="3"
            :placeholder="placeholder"
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
          {{ loading ? 'Đang xử lý…' : confirmLabel }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';

withDefaults(defineProps<{
  title: string;
  message: string;
  confirmLabel?: string;
  placeholder?: string;
  loading?: boolean;
}>(), {
  confirmLabel: 'Xác nhận',
  placeholder: 'Ghi chú thêm (không bắt buộc)…',
  loading: false,
});

const emit = defineEmits<{
  (e: 'confirm', note: string): void;
  (e: 'cancel'): void;
}>();

const note = ref('');

const noteId = computed(() => `dialog-note-${Math.random().toString(36).slice(2)}`);
const titleId = computed(() => `dialog-title-${Math.random().toString(36).slice(2)}`);

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
  background: #15803d;
  border: 1px solid #15803d;
  color: white;
}
.confirm-btn:hover:not(:disabled) { background: #166534; }
</style>
