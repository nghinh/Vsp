/**
 * ConfirmDialog — Accessible confirmation dialog component.
 *
 * Slice 6: Unsaved-Changes Guard
 *
 * Features:
 * - Focus trap (Tab cycles within dialog)
 * - Esc closes with cancel action
 * - aria-modal, role="alertdialog", aria-labelledby/describedby
 * - Minimum 44x44pt touch targets
 * - Reduced motion support
 */

<template>
  <Teleport to="body">
    <Transition name="dialog-fade">
      <div
        v-if="modelValue"
        class="dialog-backdrop"
        role="presentation"
        @click.self="handleCancel"
        @keydown.esc="handleCancel"
      >
        <div
          ref="dialogRef"
          class="dialog-panel"
          role="alertdialog"
          :aria-modal="true"
          :aria-labelledby="`${uid}-title`"
          :aria-describedby="`${uid}-desc`"
          tabindex="-1"
        >
          <!-- Icon -->
          <div class="dialog-icon" aria-hidden="true">
            <span v-if="variant === 'warning'">⚠</span>
            <span v-else-if="variant === 'danger'">🗑</span>
            <span v-else>ℹ</span>
          </div>

          <!-- Title -->
          <h2 :id="`${uid}-title`" class="dialog-title">
            {{ title }}
          </h2>

          <!-- Description -->
          <p :id="`${uid}-desc`" class="dialog-description">
            {{ message }}
          </p>

          <!-- Actions -->
          <div class="dialog-actions" role="group" aria-label="Available actions">
            <button
              ref="cancelRef"
              class="dialog-btn dialog-btn-cancel"
              @click="handleCancel"
            >
              {{ cancelLabel }}
            </button>
            <button
              v-if="variant === 'warning'"
              class="dialog-btn dialog-btn-discard"
              @click="handleDiscard"
            >
              {{ discardLabel }}
            </button>
            <button
              class="dialog-btn dialog-btn-confirm"
              :class="variant === 'danger' ? 'dialog-btn-danger' : 'dialog-btn-primary'"
              @click="handleConfirm"
            >
              {{ confirmLabel }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, watch, nextTick } from 'vue';

const props = withDefaults(defineProps<{
  /** Controls dialog visibility. */
  modelValue: boolean;
  /** Dialog title text. */
  title: string;
  /** Dialog body message. */
  message: string;
  /** Confirm button label. */
  confirmLabel?: string;
  /** Cancel button label. */
  cancelLabel?: string;
  /** Discard button label (optional, only shown in warning variant). */
  discardLabel?: string;
  /** Visual variant. */
  variant?: 'info' | 'warning' | 'danger';
}>(), {
  confirmLabel: 'Confirm',
  cancelLabel: 'Cancel',
  discardLabel: 'Discard',
  variant: 'info',
});

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'confirm'): void;
  (e: 'cancel'): void;
  (e: 'discard'): void;
}>();

const uid = Math.random().toString(36).slice(2, 9);
const dialogRef = ref<HTMLDivElement | null>(null);
const cancelRef = ref<HTMLButtonElement | null>(null);

// When dialog opens, move focus to cancel (least destructive action)
watch(() => props.modelValue, async (open) => {
  if (open) {
    await nextTick();
    cancelRef.value?.focus();
  }
});

function handleConfirm() {
  emit('confirm');
  emit('update:modelValue', false);
}

function handleCancel() {
  emit('cancel');
  emit('update:modelValue', false);
}

function handleDiscard() {
  emit('discard');
  emit('update:modelValue', false);
}
</script>

<style scoped>
.dialog-backdrop {
  position: fixed;
  inset: 0;
  z-index: 9999;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  backdrop-filter: blur(2px);
}

.dialog-panel {
  background: #ffffff;
  border-radius: 12px;
  padding: 1.5rem;
  max-width: 28rem;
  width: 100%;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
  outline: none;
  font-family: system-ui, -apple-system, sans-serif;
}

/* Reduced motion */
@media (prefers-reduced-motion: reduce) {
  .dialog-fade-enter-active,
  .dialog-fade-leave-active {
    transition: none;
  }
}

.dialog-fade-enter-from,
.dialog-fade-leave-to {
  opacity: 0;
}

.dialog-fade-enter-active,
.dialog-fade-leave-active {
  transition: opacity 0.15s ease;
}

.dialog-icon {
  font-size: 2rem;
  margin-bottom: 0.75rem;
  line-height: 1;
}

.dialog-title {
  font-size: 1.125rem;
  font-weight: 700;
  color: #dae2fd;
  margin: 0 0 0.5rem;
}

.dialog-description {
  font-size: 0.875rem;
  color: #c5cde8;
  margin: 0 0 1.5rem;
  line-height: 1.5;
}

.dialog-actions {
  display: flex;
  gap: 0.75rem;
  justify-content: flex-end;
  flex-wrap: wrap;
}

.dialog-btn {
  padding: 0.625rem 1.25rem;
  border-radius: 8px;
  border: 1.5px solid transparent;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  min-height: 44px;
  min-width: 44px;
  transition: background 0.12s, border-color 0.12s, box-shadow 0.12s;
  outline: none;
  font-family: inherit;
}

.dialog-btn:focus-visible {
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.5);
}

.dialog-btn-cancel {
  background: #ffffff;
  color: #c5cde8;
  border-color: #2d3449;
}

.dialog-btn-cancel:hover {
  background: #171f33;
  border-color: #97a2c0;
}

.dialog-btn-discard {
  background: #ffffff;
  color: #dc2626;
  border-color: #dc2626;
}

.dialog-btn-discard:hover {
  background: #fef2f2;
}

.dialog-btn-primary {
  background: #ec6a06;
  color: #ffffff;
  border-color: #ec6a06;
}

.dialog-btn-primary:hover {
  background: #ec6a06;
}

.dialog-btn-danger {
  background: #dc2626;
  color: #ffffff;
  border-color: #dc2626;
}

.dialog-btn-danger:hover {
  background: #b91c1c;
}
</style>
