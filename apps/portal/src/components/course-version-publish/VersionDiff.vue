<template>
  <div
    class="version-diff"
    role="region"
    aria-label="Tóm tắt so sánh phiên bản"
  >
    <!-- Diff header -->
    <div class="diff-header">
      <h3 class="diff-title">Thay đổi so với lần công bố trước</h3>
      <div class="version-ids" aria-label="So sánh phiên bản">
        <span class="version-chip draft-chip">
          Bản nháp v{{ diff.draftVersionId }}
        </span>
        <span class="arrow" aria-hidden="true">&#8594;</span>
        <span v-if="diff.publishedVersionId" class="version-chip published-chip">
          Đã publish v{{ diff.publishedVersionId }}
        </span>
        <span v-else class="version-chip no-published-chip">Chưa có bản công bố</span>
      </div>
    </div>

    <!-- Summary counts -->
    <div class="diff-summary" aria-label="Tóm tắt thay đổi">
      <button
        class="summary-count added-count"
        :class="{ expanded: expandedSection === 'added' }"
        :aria-expanded="expandedSection === 'added'"
        aria-controls="diff-added"
        @click="toggleSection('added')"
      >
        <span class="count-icon" aria-hidden="true">+</span>
        <span class="count-num">{{ diff.added.length }}</span>
        <span class="count-label">Thêm mới</span>
      </button>
      <button
        class="summary-count removed-count"
        :class="{ expanded: expandedSection === 'removed' }"
        :aria-expanded="expandedSection === 'removed'"
        aria-controls="diff-removed"
        @click="toggleSection('removed')"
      >
        <span class="count-icon" aria-hidden="true">&#8722;</span>
        <span class="count-num">{{ diff.removed.length }}</span>
        <span class="count-label">Đã xoá</span>
      </button>
      <button
        class="summary-count changed-count"
        :class="{ expanded: expandedSection === 'changed' }"
        :aria-expanded="expandedSection === 'changed'"
        aria-controls="diff-changed"
        @click="toggleSection('changed')"
      >
        <span class="count-icon" aria-hidden="true">&#8764;</span>
        <span class="count-num">{{ diff.changed.length }}</span>
        <span class="count-label">Đã đổi</span>
      </button>
    </div>

    <!-- Expanded sections -->
    <div class="diff-sections">

      <!-- Added entities -->
      <div
        v-if="expandedSection === 'added'"
        id="diff-added"
        class="diff-section"
        role="region"
        aria-label="Đối tượng thêm mới"
      >
        <h4 class="section-label added-label">
          <span aria-hidden="true">+</span> Thêm ({{ diff.added.length }})
        </h4>
        <ul v-if="diff.added.length" class="entry-list" role="list">
          <li
            v-for="(entry, idx) in diff.added"
            :key="`added-${idx}`"
            class="diff-entry added-entry"
          >
            <span class="entry-entity">{{ entry.entity }}</span>
            <span v-if="entry.entityId" class="entry-id">#{{ entry.entityId }}</span>
            <span class="entry-field">{{ entry.field }}</span>
          </li>
        </ul>
        <p v-else class="empty-section">Không có đối tượng nào được thêm.</p>
      </div>

      <!-- Removed entities -->
      <div
        v-if="expandedSection === 'removed'"
        id="diff-removed"
        class="diff-section"
        role="region"
        aria-label="Đối tượng bị xoá"
      >
        <h4 class="section-label removed-label">
          <span aria-hidden="true">&#8722;</span> Bỏ ({{ diff.removed.length }})
        </h4>
        <ul v-if="diff.removed.length" class="entry-list" role="list">
          <li
            v-for="(entry, idx) in diff.removed"
            :key="`removed-${idx}`"
            class="diff-entry removed-entry"
          >
            <span class="entry-entity">{{ entry.entity }}</span>
            <span v-if="entry.entityId" class="entry-id">#{{ entry.entityId }}</span>
            <span class="entry-field">{{ entry.field }}</span>
          </li>
        </ul>
        <p v-else class="empty-section">Không có đối tượng nào bị xoá.</p>
      </div>

      <!-- Changed entities -->
      <div
        v-if="expandedSection === 'changed'"
        id="diff-changed"
        class="diff-section"
        role="region"
        aria-label="Đối tượng thay đổi"
      >
        <h4 class="section-label changed-label">
          <span aria-hidden="true">&#8764;</span> Đổi ({{ diff.changed.length }})
        </h4>
        <ul v-if="diff.changed.length" class="entry-list changed-list" role="list">
          <li
            v-for="(entry, idx) in diff.changed"
            :key="`changed-${idx}`"
            class="diff-entry changed-entry"
          >
            <div class="changed-header">
              <span class="entry-entity">{{ entry.entity }}</span>
              <span v-if="entry.entityId" class="entry-id">#{{ entry.entityId }}</span>
              <span class="entry-field">{{ entry.field }}</span>
            </div>
            <div class="changed-values">
              <span v-if="entry.oldValue !== null" class="value-chip old-value" aria-label="Giá trị cũ">
                <span class="value-label">trước</span>
                <span class="value-text">{{ truncate(entry.oldValue, 60) }}</span>
              </span>
              <span v-if="entry.newValue !== null" class="value-chip new-value" aria-label="Giá trị mới">
                <span class="value-label">sau</span>
                <span class="value-text">{{ truncate(entry.newValue, 60) }}</span>
              </span>
            </div>
          </li>
        </ul>
        <p v-else class="empty-section">Không có đối tượng nào thay đổi.</p>
      </div>

    </div>

    <!-- Expand all hint -->
    <div class="expand-hint" aria-hidden="true">
      Bấm vào con số để xem chi tiết.
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { VersionDiff } from '@/types/course-version-publish';

type DiffSection = 'added' | 'removed' | 'changed';

defineProps<{
  diff: VersionDiff;
}>();

const expandedSection = ref<DiffSection | null>('changed');

function toggleSection(section: DiffSection) {
  expandedSection.value = expandedSection.value === section ? null : section;
}

function truncate(val: string, maxLen: number): string {
  if (val.length <= maxLen) return val;
  return val.slice(0, maxLen) + '…';
}
</script>

<style scoped>
.version-diff {
  font-family: var(--vsp-font-body, system-ui, -apple-system, sans-serif);
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-3, 12px);
  padding: var(--vsp-space-4, 16px);
  border-radius: var(--vsp-radius-md, 8px);
  background: var(--vsp-color-surface, #fff);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
}

/* Header */
.diff-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: var(--vsp-space-2, 8px);
}

.diff-title {
  font-size: var(--vsp-font-size-base, 1rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  color: var(--vsp-color-text-primary, #0F172A);
  margin: 0;
}

.version-ids {
  display: flex;
  align-items: center;
  gap: var(--vsp-space-2, 8px);
  flex-wrap: wrap;
}

.version-chip {
  font-family: var(--vsp-font-mono, monospace);
  font-size: var(--vsp-font-size-xs, 0.75rem);
  padding: 2px var(--vsp-space-2, 8px);
  border-radius: var(--vsp-radius-sm, 4px);
  border: 1px solid currentColor;
}

.draft-chip {
  color: var(--vsp-color-primary, #EA580C);
  background: color-mix(in srgb, var(--vsp-color-primary, #EA580C) 10%, transparent);
}

.published-chip {
  color: var(--vsp-color-official, #059669);
  background: color-mix(in srgb, var(--vsp-color-official, #059669) 10%, transparent);
}

.no-published-chip {
  color: var(--vsp-color-text-tertiary, #94A3B8);
  background: var(--vsp-color-muted, #F8FAFC);
}

.arrow {
  color: var(--vsp-color-text-tertiary, #94A3B8);
  font-size: var(--vsp-font-size-sm, 0.875rem);
}

/* Summary counts */
.diff-summary {
  display: flex;
  gap: var(--vsp-space-2, 8px);
  flex-wrap: wrap;
}

.summary-count {
  display: inline-flex;
  align-items: center;
  gap: var(--vsp-space-1, 4px);
  padding: var(--vsp-space-1, 4px) var(--vsp-space-3, 12px);
  border-radius: var(--vsp-radius-md, 8px);
  border: 1px solid var(--vsp-color-border-strong, rgba(15, 23, 42, 0.16));
  background: var(--vsp-color-muted, #F8FAFC);
  cursor: pointer;
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-medium, 500);
  font-family: inherit;
  transition: border-color var(--vsp-duration-press, 80ms) var(--vsp-easing-deceleration, ease-out);
  min-height: var(--vsp-touch-target-min, 44px);
  color: var(--vsp-color-text-primary, #0F172A);
}

.summary-count:hover {
  border-color: var(--vsp-color-border-strong, rgba(15, 23, 42, 0.16));
  background: var(--vsp-color-border, rgba(15, 23, 42, 0.08));
}

.summary-count:focus-visible {
  outline: none;
  box-shadow: var(--vsp-focus-ring, 0 0 0 2px var(--vsp-color-ring, #EA580C));
}

.summary-count.expanded {
  border-color: var(--vsp-color-primary, #EA580C);
  background: color-mix(in srgb, var(--vsp-color-primary, #EA580C) 10%, transparent);
  color: var(--vsp-color-primary, #EA580C);
}

.added-count .count-icon { color: var(--vsp-color-official, #059669); font-weight: 700; }
.removed-count .count-icon { color: var(--vsp-color-destructive, #DC2626); font-weight: 700; }
.changed-count .count-icon { color: var(--vsp-color-secondary, #F97316); font-weight: 700; }

.count-num {
  font-family: var(--vsp-font-mono, monospace);
  font-weight: var(--vsp-font-weight-bold, 700);
  font-size: var(--vsp-font-size-base, 1rem);
}

.count-label {
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-secondary, #475569);
}

/* Sections */
.diff-sections {
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-2, 8px);
}

.diff-section {
  padding: var(--vsp-space-3, 12px);
  border-radius: var(--vsp-radius-md, 8px);
  background: var(--vsp-color-muted, #F8FAFC);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
}

.section-label {
  display: flex;
  align-items: center;
  gap: var(--vsp-space-1, 4px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
  font-weight: var(--vsp-font-weight-semibold, 600);
  margin: 0 0 var(--vsp-space-2, 8px) 0;
}

.added-label { color: var(--vsp-color-official, #059669); }
.removed-label { color: var(--vsp-color-destructive, #DC2626); }
.changed-label { color: var(--vsp-color-secondary, #F97316); }

.entry-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-1, 4px);
}

.diff-entry {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: var(--vsp-space-2, 8px);
  padding: var(--vsp-space-1, 4px) var(--vsp-space-2, 8px);
  border-radius: var(--vsp-radius-sm, 4px);
  font-size: var(--vsp-font-size-sm, 0.875rem);
}

.added-entry { background: color-mix(in srgb, var(--vsp-color-official, #059669) 6%, transparent); }
.removed-entry { background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 6%, transparent); }
.changed-entry {
  background: var(--vsp-color-surface, #fff);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  flex-direction: column;
  gap: var(--vsp-space-1, 4px);
}

.entry-entity {
  font-weight: var(--vsp-font-weight-semibold, 600);
  color: var(--vsp-color-text-primary, #0F172A);
}

.entry-id {
  font-family: var(--vsp-font-mono, monospace);
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
}

.entry-field {
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-secondary, #475569);
  background: var(--vsp-color-muted, #F8FAFC);
  border: 1px solid var(--vsp-color-border, rgba(15, 23, 42, 0.08));
  border-radius: var(--vsp-radius-sm, 4px);
  padding: 1px var(--vsp-space-1, 4px);
  font-family: var(--vsp-font-mono, monospace);
}

.changed-header {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: var(--vsp-space-2, 8px);
}

.changed-values {
  display: flex;
  flex-direction: column;
  gap: var(--vsp-space-1, 4px);
  padding-left: var(--vsp-space-2, 8px);
}

.value-chip {
  display: inline-flex;
  align-items: baseline;
  gap: var(--vsp-space-1, 4px);
  font-size: var(--vsp-font-size-xs, 0.75rem);
  font-family: var(--vsp-font-mono, monospace);
  border-radius: var(--vsp-radius-sm, 4px);
  padding: 1px var(--vsp-space-1, 4px);
}

.value-label {
  font-weight: var(--vsp-font-weight-semibold, 600);
  font-size: 0.6875rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.old-value {
  color: var(--vsp-color-destructive, #DC2626);
  background: color-mix(in srgb, var(--vsp-color-destructive, #DC2626) 8%, transparent);
  text-decoration: line-through;
  opacity: 0.8;
}

.new-value {
  color: var(--vsp-color-official, #059669);
  background: color-mix(in srgb, var(--vsp-color-official, #059669) 8%, transparent);
}

.empty-section {
  font-size: var(--vsp-font-size-sm, 0.875rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
  margin: 0;
  font-style: italic;
}

.expand-hint {
  font-size: var(--vsp-font-size-xs, 0.75rem);
  color: var(--vsp-color-text-tertiary, #94A3B8);
  text-align: right;
}
</style>
