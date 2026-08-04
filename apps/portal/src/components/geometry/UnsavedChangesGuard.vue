/**
 * UnsavedChangesGuard — Route-guard dialog for unsaved geometry edits.
 *
 * Slice 6: Unsaved-Change Guard
 *
 * Shows a confirmation dialog when the user tries to navigate away
 * with unsaved changes. Options: Save Draft, Discard, Cancel.
 */

<template>
  <ConfirmDialog
    v-model="isDialogOpen"
    variant="warning"
    :title="title"
    :message="message"
    :confirm-label="saveLabel"
    :discard-label="discardLabel"
    :cancel-label="cancelLabel"
    @confirm="handleSave"
    @discard="handleDiscard"
    @cancel="handleCancel"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import ConfirmDialog from './ConfirmDialog.vue';

const props = withDefaults(defineProps<{
  /** Controls dialog visibility. */
  modelValue: boolean;
  /** Dialog title. */
  title?: string;
  /** Dialog message. */
  message?: string;
  /** Save button label. */
  saveLabel?: string;
  /** Discard button label. */
  discardLabel?: string;
  /** Cancel button label. */
  cancelLabel?: string;
}>(), {
  title: 'Unsaved Changes',
  message: 'You have unsaved geometry edits. What would you like to do?',
  saveLabel: 'Save Draft',
  discardLabel: 'Discard',
  cancelLabel: 'Cancel',
});

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'save'): void;
  (e: 'discard'): void;
  (e: 'cancel'): void;
}>();

const isDialogOpen = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
});

function handleSave() {
  emit('save');
}

function handleDiscard() {
  emit('discard');
}

function handleCancel() {
  emit('cancel');
}
</script>
