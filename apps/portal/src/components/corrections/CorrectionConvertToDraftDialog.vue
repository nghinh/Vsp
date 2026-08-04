<template>
  <div class="dialog-overlay" role="dialog" aria-modal="true" aria-labelledby="convert-title">
    <div class="dialog-panel">
      <div class="dialog-header">
        <h2 id="convert-title" class="dialog-title">Convert to Draft Edit</h2>
        <button class="close-btn" @click="$emit('cancel')" aria-label="Close dialog">×</button>
      </div>

      <div class="dialog-body">
        <div class="convert-notice">
          <span aria-hidden="true">📝</span>
          <p>
            Converting this correction to a draft edit will create a draft in the
            geometry editor. You can then refine and publish it as part of the
            normal editing workflow.
          </p>
        </div>

        <div class="form-field">
          <label for="convert-note" class="field-label">
            Note <span class="optional">(optional)</span>
          </label>
          <textarea
            id="convert-note"
            v-model="note"
            class="field-input"
            rows="3"
            placeholder="Optional note about this conversion…"
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
          {{ loading ? 'Creating…' : 'Convert to Draft' }}
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
