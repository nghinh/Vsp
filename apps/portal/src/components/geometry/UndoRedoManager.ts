/**
 * UndoRedoManager — Command-pattern undo/redo stack for the geometry editor.
 *
 * Slice 5: Undo/Redo Stack
 *
 * Operations tracked:
 * - Add feature
 * - Delete feature
 * - Move vertex
 * - Add vertex
 * - Delete vertex
 * - Modify geometry property
 *
 * Usage:
 *   const manager = createUndoRedoManager();
 *   manager.push(manager.commands.addFeature(feature));
 *   manager.undo();  // returns { type: 'add', feature } → caller removes it
 *   manager.redo();  // re-applies
 */

import type {
  GeometryFeature,
  LayerType,
} from '@/types/geometry';

// ─── Command types ────────────────────────────────────────────────────────────

export type CommandType =
  | 'add_feature'
  | 'delete_feature'
  | 'modify_feature'
  | 'move_vertex'
  | 'add_vertex'
  | 'delete_vertex';

export interface EditCommand {
  /** Unique identifier for this command. */
  id: string;
  type: CommandType;
  layerType: LayerType;
  /** Snapshot of the feature(s) before this command. */
  before: GeometryFeature[];
  /** Snapshot of the feature(s) after this command. */
  after: GeometryFeature[];
  /** Human-readable description for undo stack display. */
  description: string;
  /** Timestamp of command creation. */
  timestamp: number;
}

// ─── Command builder ─────────────────────────────────────────────────────────

export interface UndoRedoManager {
  /**
   * Push a new command onto the undo stack.
   * Calling push() clears the redo stack.
   */
  push(cmd: EditCommand): void;
  /**
   * Pop and return the most recent command from the undo stack.
   * The caller should apply the `before` state.
   * Returns undefined if undo stack is empty.
   */
  undo(): EditCommand | undefined;
  /**
   * Pop and return the most recent undone command from the redo stack.
   * The caller should apply the `after` state.
   * Returns undefined if redo stack is empty.
   */
  redo(): EditCommand | undefined;
  /**
   * Number of undo steps available.
   */
  readonly canUndo: number;
  /**
   * Number of redo steps available.
   */
  readonly canRedo: number;
  /**
   * Whether there are unsaved changes (undo stack non-empty).
   */
  readonly isDirty: boolean;
  /**
   * Clear both undo and redo stacks.
   */
  reset(): void;
  /**
   * Mark the current state as saved — clears undo stack without losing redo.
   * Called after a successful save to draft/publish.
   */
  markSaved(): void;
}

let _idCounter = 0;
function nextId(): string {
  return `cmd-${Date.now()}-${++_idCounter}`;
}

// ─── Factory ────────────────────────────────────────────────────────────────

export function createUndoRedoManager(): UndoRedoManager {
  const undoStack: EditCommand[] = [];
  const redoStack: EditCommand[] = [];

  return {
    push(cmd: EditCommand) {
      undoStack.push(cmd);
      redoStack.length = 0; // Clear redo on new action
    },

    undo(): EditCommand | undefined {
      const cmd = undoStack.pop();
      if (cmd) redoStack.push(cmd); // move onto the redo stack so redo can re-apply
      return cmd;
    },

    redo(): EditCommand | undefined {
      const cmd = redoStack.pop();
      if (cmd) undoStack.push(cmd); // move back onto the undo stack
      return cmd;
    },

    get canUndo() { return undoStack.length; },
    get canRedo() { return redoStack.length; },
    get isDirty() { return undoStack.length > 0; },

    reset() {
      undoStack.length = 0;
      redoStack.length = 0;
    },

    markSaved() {
      // After a successful save, the undo stack represents saved state.
      // We keep the redo stack (user can redo after save) but the caller
      // should consider the document no longer dirty from the user's perspective.
      // For safety, we just clear undo — the server state is now the baseline.
      undoStack.length = 0;
    },
  };
}

// ─── Command constructors ───────────────────────────────────────────────────

export function cmdAddFeature(feature: GeometryFeature): EditCommand {
  return {
    id: nextId(),
    type: 'add_feature',
    layerType: feature.properties.layerType,
    before: [],
    after: [feature],
    description: `Add ${feature.properties.layerType}`,
    timestamp: Date.now(),
  };
}

export function cmdDeleteFeature(feature: GeometryFeature): EditCommand {
  return {
    id: nextId(),
    type: 'delete_feature',
    layerType: feature.properties.layerType,
    before: [feature],
    after: [],
    description: `Delete ${feature.properties.layerType}`,
    timestamp: Date.now(),
  };
}

export function cmdModifyFeature(
  before: GeometryFeature,
  after: GeometryFeature
): EditCommand {
  return {
    id: nextId(),
    type: 'modify_feature',
    layerType: before.properties.layerType,
    before: [before],
    after: [after],
    description: `Modify ${before.properties.layerType}`,
    timestamp: Date.now(),
  };
}

export function cmdMoveVertex(
  feature: GeometryFeature,
  vertexIndex: number,
  _beforeCoord: [number, number],
  _afterCoord: [number, number],
  newFeature: GeometryFeature
): EditCommand {
  return {
    id: nextId(),
    type: 'move_vertex',
    layerType: feature.properties.layerType,
    before: [feature],
    after: [newFeature],
    description: `Move vertex ${vertexIndex} on ${feature.properties.layerType}`,
    timestamp: Date.now(),
  };
}

export function cmdAddVertex(
  feature: GeometryFeature,
  _afterIndex: number,
  newFeature: GeometryFeature
): EditCommand {
  return {
    id: nextId(),
    type: 'add_vertex',
    layerType: feature.properties.layerType,
    before: [feature],
    after: [newFeature],
    description: `Add vertex to ${feature.properties.layerType}`,
    timestamp: Date.now(),
  };
}

export function cmdDeleteVertex(
  feature: GeometryFeature,
  deletedFeature: GeometryFeature | null,
  vertexIndex: number
): EditCommand {
  return {
    id: nextId(),
    type: 'delete_vertex',
    layerType: feature.properties.layerType,
    before: deletedFeature ? [feature, deletedFeature] : [feature],
    after: deletedFeature ? [deletedFeature] : [],
    description: `Delete vertex ${vertexIndex} from ${feature.properties.layerType}`,
    timestamp: Date.now(),
  };
}

// ─── Keyboard shortcut handler ──────────────────────────────────────────────

export interface KeyboardShortcutOptions {
  onUndo: () => void;
  onRedo: () => void;
  /** Additional shortcuts as key → handler map. */
  extraShortcuts?: Record<string, () => void>;
}

/**
 * Attach a keydown listener for undo/redo shortcuts.
 * Returns a cleanup function.
 *
 * Shortcuts:
 *   Ctrl+Z / Cmd+Z   → onUndo
 *   Ctrl+Shift+Z / Cmd+Shift+Z → onRedo
 *   Ctrl+Y / Cmd+Y   → onRedo (Windows alternative)
 */
export function attachEditorShortcuts(
  options: KeyboardShortcutOptions
): () => void {
  function handler(event: KeyboardEvent) {
    const isMac = navigator.platform.toUpperCase().includes('MAC');
    const ctrlKey = isMac ? event.metaKey : event.ctrlKey;

    if (ctrlKey && event.key === 'z') {
      if (event.shiftKey) {
        event.preventDefault();
        options.onRedo();
      } else {
        event.preventDefault();
        options.onUndo();
      }
      return;
    }

    if (ctrlKey && (event.key === 'y' || event.key === 'Y')) {
      // Windows: Ctrl+Y = redo
      event.preventDefault();
      options.onRedo();
      return;
    }

    // Extra shortcuts
    const extra = options.extraShortcuts?.[event.key];
    if (extra && !ctrlKey && !event.metaKey && !event.altKey) {
      extra();
    }
  }

  window.addEventListener('keydown', handler);
  return () => window.removeEventListener('keydown', handler);
}
