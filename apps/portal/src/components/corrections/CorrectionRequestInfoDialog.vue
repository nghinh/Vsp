<template>
  <div class="dialog-overlay" role="dialog" aria-modal="true" aria-labelledby="request-info-title">
    <div class="dialog-panel">
      <div class="dialog-header">
        <h2 id="request-info-title" class="dialog-title">Request More Information</h2>
        <button class="close-btn" @click="$emit('cancel')" aria-label="Close dialog">×</button>
      </div>

      <div class="dialog-body">
        <p class="dialog-message">
          Send a message to the reporter requesting additional information.
          The correction will be marked as "Info Requested".
        </p>

        <div class="form-field">
          <label for="info-message" class="field-label">
            Message to Reporter <span class="required" aria-hidden="true">*</span>
          </label>
          <textarea
            id="info-message"
            v-model="message"
            class="field-input"
            rows="4"
            placeholder="What additional information would help you evaluate this correction?…"
            maxlength="500"
            :aria-invalid="messageError ? 'true' : undefined"
            :aria-describedby="messageError ? 'message-error' : undefined"
          ></textarea>
          <span v-if="messageError" id="message-error" class="field-error" role="alert">
            {{ messageError }}
          </span>
          <span class="field-hint">{{ message.length }}/500 characters</span>
        </div>

        <div class="form-field">
          <label for="info-note" class="field-label">
            Internal Note <span class="optional">(optional)</span>
          </label>
          <textarea
            id="info-note"
            v-model="note"
            class="field-input"
            rows="2"
            placeholder="Optional internal note for the audit trail…"
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
          {{ loading ? 'Sending…' : 'Send Request' }}
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
    messageError.value = 'A message is required to request more information.';
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
  background: #171f33;
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
.optional { font-weight: 400; color: #97a2c0; }
.field-input {
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
.field-input[aria-invalid="true"] { border-color: #dc2626; }
.field-error { font-size: 0.75rem; color: #dc2626; }
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
  background: #7c3aed;
  border: 1px solid #7c3aed;
  color: white;
}
.confirm-btn:hover:not(:disabled) { background: #6d28d9; }
</style>
