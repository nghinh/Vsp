<template>
  <span
    class="draft-indicator"
    :class="variantClass"
    role="status"
    :aria-label="`Trạng thái hình học: ${label}`"
  >
    <span class="indicator-dot" aria-hidden="true" />
    <span class="indicator-label">{{ label }}</span>
    <span v-if="showVersion && version != null" class="indicator-version">v{{ version }}</span>
  </span>
</template>

<script setup lang="ts">
/**
 * DraftIndicator — badge component showing draft vs published geometry state.
 *
 * Slice 2: MapLibre Integration for Portal
 *
 * Displays:
 * - "Bản nháp" badge (amber) when the geometry is unsaved / in-edit mode
 * - "Đã publish" badge (green) when the geometry has been published
 * - Version number when available
 */

import { computed } from 'vue';

const props = defineProps<{
  /** Whether the current geometry is a draft (vs published). */
  isDraft: boolean;
  /** Geometry version number (shown as v{version}). */
  version?: number | null;
  /** Show version badge alongside the state label. */
  showVersion?: boolean;
}>();

const label = computed(() => props.isDraft ? 'Bản nháp' : 'Đã publish');

const variantClass = computed(() =>
  props.isDraft ? 'indicator-draft' : 'indicator-published'
);
</script>

<style scoped>
.draft-indicator {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid currentColor;
  white-space: nowrap;
  font-family: system-ui, -apple-system, sans-serif;
}

.indicator-dot {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 50%;
  background: currentColor;
  flex-shrink: 0;
}

/* Draft variant */
.indicator-draft {
  color: #f0c869;
  background: rgba(240, 180, 41, 0.14);
}

/* Published variant */
.indicator-published {
  color: #6ee7a8;
  background: rgba(34, 197, 94, 0.14);
}

/* Version badge */
.indicator-version {
  font-size: 0.6875rem;
  opacity: 0.7;
  margin-left: 0.125rem;
}
</style>
