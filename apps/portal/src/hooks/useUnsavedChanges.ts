/**
 * useUnsavedChanges — Vue composable to track dirty state and trigger
 * confirmation when the user tries to navigate away.
 *
 * Slice 6: Unsaved-Changes Guard
 */

import { ref, onUnmounted } from 'vue';

export type DirtyReason =
  | 'feature_added'
  | 'feature_modified'
  | 'feature_deleted'
  | 'vertex_moved'
  | 'vertex_added'
  | 'vertex_deleted';

export interface UnsavedChangesOptions {
  /** Called when the user chooses to save. */
  onSave: () => Promise<void>;
  /** Called when the user chooses to discard. */
  onDiscard: () => void;
  /** Called when the user cancels the navigation. */
  onCancel?: () => void;
}

export function useUnsavedChanges(options: UnsavedChangesOptions) {
  const isDirty = ref(false);
  const isDialogOpen = ref(false);
  const pendingNavigation = ref<(() => void) | null>(null);
  const dirtyReasons = ref<DirtyReason[]>([]);

  function markDirty(reason: DirtyReason) {
    isDirty.value = true;
    if (!dirtyReasons.value.includes(reason)) {
      dirtyReasons.value.push(reason);
    }
  }

  function markClean() {
    isDirty.value = false;
    dirtyReasons.value = [];
  }

  /**
   * Attempt to navigate away. If dirty, opens the confirmation dialog
   * instead of navigating immediately. The caller provides a function that
   * performs the actual navigation; it will be called only after the
   * user confirms or if the document is clean.
   *
   * Usage:
   *   const { guardNavigation } = useUnsavedChanges(...);
   *   guardNavigation(() => router.push('/other-page'));
   */
  function guardNavigation(navigate: () => void) {
    if (isDirty.value) {
      pendingNavigation.value = navigate;
      isDialogOpen.value = true;
    } else {
      navigate();
    }
  }

  async function handleSave() {
    isDialogOpen.value = false;
    try {
      await options.onSave();
      markClean();
      pendingNavigation.value?.();
      pendingNavigation.value = null;
    } catch {
      // Save failed — keep dialog open so user can retry or discard
    }
  }

  function handleDiscard() {
    isDialogOpen.value = false;
    markClean();
    pendingNavigation.value?.();
    pendingNavigation.value = null;
    options.onDiscard();
  }

  function handleCancel() {
    isDialogOpen.value = false;
    pendingNavigation.value = null;
    options.onCancel?.();
  }

  // Browser beforeunload — always fire if dirty
  function handleBeforeUnload(event: BeforeUnloadEvent) {
    if (isDirty.value) {
      event.preventDefault();
      event.returnValue = '';
    }
  }

  const removeListener = () => {
    window.removeEventListener('beforeunload', handleBeforeUnload);
  };

  window.addEventListener('beforeunload', handleBeforeUnload);
  onUnmounted(removeListener);

  return {
    isDirty,
    isDialogOpen,
    dirtyReasons,
    markDirty,
    markClean,
    guardNavigation,
    handleSave,
    handleDiscard,
    handleCancel,
  };
}
