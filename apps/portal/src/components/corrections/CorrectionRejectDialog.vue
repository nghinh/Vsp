<template>
  <div class="dialog-overlay" role="dialog" aria-modal="true" aria-labelledby="reject-title">
    <div class="dialog-panel">
      <div class="dialog-header">
        <h2 id="reject-title" class="dialog-title">Reject Correction</h2>
        <button class="close-btn" @click="$emit('cancel')" aria-label="Close dialog">×</button>
      </div>

      <div class="dialog-body">
        <p class="dialog-message">
          Please provide a reason for rejecting this correction. This will be visible
          in the audit trail.
        </p>

        <div class="form-field">
          <label for="reject-reason" class="field-label">
            Reason <span class="required" aria-hidden="true">*</span>
          </label>
          <textarea
            id="reject-reason"
            v-model="reason"
            class="field-input"
            rows="3"
            placeholder="Explain why this correction is being rejected…"
            maxlength="500"
            :aria-invalid="reasonError ? 'true' : undefined"
            :aria-describedby="reasonError ? 'reason-error' : undefined"
          ></textarea>
          <span v-if="reasonError" id="reason-error" class="field-error" role="alert">
            {{ reasonError }}
          </span>
          <span class="field-hint">{{ reason.length }}/500 characters</span>
        </div>

        <div class="form-field">
          <label for="reject-note" class="field-label">
            Internal Note <span class="optional">(optional)</span>
          </label>
          <textarea
            id="reject-note"
            v-model="note"
            class="field-input"
            rows="2"
            placeholder="Optional note for the audit trail…"
            maxlength="500"
          ></textarea>
          <span class="field-hint">{{ note.length }}/500 characters</span>
        </div>
      </div>

      <div class="dialog-footer">
        <button class="action-btn cancel-btn" @click="$emit('cancel')" :disabled="loading">
          Cancel
        </button>
        <button
          class="action-btn confirm-btn"
          :disabled="loading"
          @click="confirm"
        >
          {{ loading ? 'Processing…' : 'Reject Correction' }}
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
    reasonError.value = 'A reason is required to reject a correction.';
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
  background: white;
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
  border-bottom: 1px solid #e5e7eb;
  background: #f9fafb;
}
.dialog-title { font-size: 1.0625rem; font-weight: 700; color: #111827; margin: 0; }
.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #6b7280;
  min-height: 44px;
  min-width: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
}
.close-btn:hover { background: #f3f4f6; }

.dialog-body {
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.dialog-message {
  font-size: 0.875rem;
  color: #374151;
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
  color: #374151;
}
.required { color: #dc2626; }
.optional { font-weight: 400; color: #9ca3af; }
.field-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
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
.field-hint { font-size: 0.75rem; color: #9ca3af; text-align: right; }

.dialog-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 0.875rem 1.25rem;
  border-top: 1px solid #e5e7eb;
  background: #f9fafb;
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
  background: white;
  border: 1px solid #d1d5db;
  color: #374151;
}
.cancel-btn:hover:not(:disabled) { background: #f3f4f6; }

.confirm-btn {
  background: #b91c1c;
  border: 1px solid #b91c1c;
  color: white;
}
.confirm-btn:hover:not(:disabled) { background: #991b1b; }
</style>
