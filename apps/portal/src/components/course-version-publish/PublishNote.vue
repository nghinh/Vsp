<template>
  <div
    class="publish-note"
    role="region"
    aria-label="Publish note"
  >
    <label class="note-label" :for="textareaId">
      Publish note
      <span class="required-asterisk" aria-hidden="true">*</span>
      <span class="required-note">(min. 10 characters)</span>
    </label>

    <textarea
      :id="textareaId"
      v-model="localNote"
      class="note-textarea"
      :class="{
        'has-error': showError,
        'has-content': localNote.length >= 10,
      }"
      :aria-describedby="showError ? `${textareaId}-error` : `${textareaId}-hint`"
      :aria-invalid="showError"
      :disabled="disabled"
      placeholder="Describe what changed in this version — e.g., Updated hole 5 fairway geometry and added new bunker on hole 12"
      rows="4"
      maxlength="2000"
      @blur="touched = true"
    ></textarea>

    <div class="note-footer">
      <span
        v-if="showError"
        :id="`${textareaId}-error`"
        class="error-message"
        role="alert"
      >
        Publish note must be at least 10 characters.
      </span>
      <span
        v-else
        :id="`${textareaId}-hint`"
        class="hint-message"
      >
        Explain what changed in this version.
      </span>
      <span
        class="char-count"
        :class="{
          'near-limit': charCount > 1900,
          'at-limit': charCount >= 2000,
        }"
        aria-label="Character count"
        aria-live="polite"
      >
        {{ charCount }}/2000
      </span>
    </div>

    <!-- Force publish checkbox (bypass quality warning) -->
    <div class="force-publish-row">
      <label class="force-label" :for="checkboxId">
        <input
          :id="checkboxId"
          v-model="localForcePublish"
          type="checkbox"
          class="force-checkbox"
          :disabled="disabled"
          aria-describedby="force-hint"
        />
        <span>Force publish</span>
      </label>
      <span id="force-hint" class="force-hint">
        Bypass quality class threshold warning (validation must still pass)
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';

const MIN_NOTE_LENGTH = 10;

const props = defineProps<{
  modelValue: { note: string; forcePublish: boolean };
  disabled?: boolean;
  forcePublishVisible?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: { note: string; forcePublish: boolean }): void;
}>();

const textareaId = 'publish-note-textarea';
const checkboxId = 'publish-note-force-checkbox';

const touched = ref(false);
const localNote = ref(props.modelValue.note);
const localForcePublish = ref(props.modelValue.forcePublish);

watch(localNote, (val) => {
  emit('update:modelValue', { note: val, forcePublish: localForcePublish.value });
});

watch(localForcePublish, (val) => {
  emit('update:modelValue', { note: localNote.value, forcePublish: val });
});

const charCount = computed(() => localNote.value.length);
const showError = computed(() => touched.value && localNote.value.length > 0 && localNote.value.length < MIN_NOTE_LENGTH);
</script>

<style scoped>
.publish-note {
  font-family: var(--vsp-font-body, system-ui, -apple-system, sans-serif);
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-2, 8px);
}

.note-label {
  display: flex;
  align-items: baseline;
  gap: var(--vsp-space-1, 4px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  color: var(--vsp-color-text-primary, #0F172A);
  cursor: pointer;
}

.required-asterisk {
  color: var(--vsp-color-destructive, #DC2626);
}

.required-note {
  font-weight: var(--vsp-font-weight-regular, 400);
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
}

.note-textarea {
  width: 100%;
  box-sizing: border-box;
  font-family: var(--vsp-font-body, system-ui, -apple-system, sans-serif);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  line-height: var(--vsp-line-height-relaxed, 1.625);
  color: var(--vsp-color-text-primary, #0F172A);
  background: var(--vsp-color-surface, #fff);
  border: 1px solid var(--vsp-color-border-strong, rgba(15, 23, 42, 0.16));
  border-radius: var(--vsp-radius-md, 8px);
  padding: var(--vsp-space-3, 12px);
  resize: vertical;
  min-height: 96px;
  transition:
    border-color var(--vsp-duration-press, 80ms) var(--vsp-easing-deceleration, ease-out),
    box-shadow var(--vsp-duration-press, 80ms) var(--vsp-easing-deceleration, ease-out);
}

.note-textarea::placeholder {
  color: var(--vsp-color-text-tertiary, #94A3B8);
}

.note-textarea:focus {
  outline: none;
  border-color: var(--vsp-color-primary, #EA580C);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--vsp-color-primary, #EA580C) 20%, transparent);
}

.note-textarea.has-error {
  border-color: var(--vsp-color-destructive, #DC2626);
}

.note-textarea.has-error:focus {
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 20%, transparent);
}

.note-textarea:disabled {
  opacity: var(--vsp-opacity-disabled, 0.5);
  cursor: not-allowed;
  background: var(--vsp-color-muted, #F8FAFC);
}

.note-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: var(--vsp-space-1, 4px);
}

.error-message {
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-destructive, #DC2626);
  font-weight: var(--vsp-font-weight-medium, 500);
}

.hint-message {
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
}

.char-count {
  font-family: var(--vsp-font-mono, monospace);
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
}

.char-count.near-limit { color: var(--vsp-color-secondary, #F97316); }
.char-count.at-limit { color: var(--vsp-color-destructive, #DC2626); }

/* Force publish */
.force-publish-row {
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-1, 4px);
  padding-top: var(--vsp-space-2, 8px);
  border-top: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
}

.force-label {
  display: flex;
  align-items: center;
  gap: var(--vsp-space-2, 8px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-medium, 500);
  color: var(--vsp-color-text-primary, #0F172A);
  cursor: pointer;
  min-height: var(--vsp-touch-target-min, 44px);
}

.force-checkbox {
  width: 18px;
  height: 18px;
  accent-color: var(--vsp-color-primary, #EA580C);
  cursor: pointer;
  flex-shrink: 0;
}

.force-checkbox:focus-visible {
  outline: none;
  box-shadow: var(--vsp-focus-ring, 0 0 0 2px var(--vsp-color-ring, #EA580C));
  border-radius: 2px;
}

.force-hint {
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
  padding-left: 26px; /* align with label text */
}
</style>
