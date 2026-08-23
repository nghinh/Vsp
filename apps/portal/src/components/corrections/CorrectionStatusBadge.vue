<template>
  <span
    class="correction-status-badge"
    :class="badgeClass"
    :aria-label="`Status: ${statusLabel(status)}`"
  >
    <span aria-hidden="true">{{ statusIcon(status) }}</span>
    <span>{{ statusLabel(status) }}</span>
  </span>
</template>

<script setup lang="ts">
import { correctionStatusLabel } from '@/lib/correction-labels';
import type { CorrectionStatusValue } from '@/types/correction';

defineProps<{
  status: CorrectionStatusValue;
}>();

function badgeClass(status: CorrectionStatusValue): string {
  switch (status) {
    case 'PENDING':           return 'badge-pending';
    case 'IN_REVIEW':        return 'badge-in-review';
    case 'APPROVED':         return 'badge-approved';
    case 'REJECTED':         return 'badge-rejected';
    case 'INFO_REQUESTED':   return 'badge-info-requested';
    case 'CONVERTED_TO_DRAFT': return 'badge-converted';
    default:                  return 'badge-unknown';
  }
}

function statusIcon(status: CorrectionStatusValue): string {
  switch (status) {
    case 'PENDING':           return '⏳';
    case 'IN_REVIEW':        return '👁';
    case 'APPROVED':         return '✅';
    case 'REJECTED':         return '❌';
    case 'INFO_REQUESTED':   return '💬';
    case 'CONVERTED_TO_DRAFT': return '📝';
    default:                  return '❓';
  }
}

const statusLabel = correctionStatusLabel;
</script>

<style scoped>
.correction-status-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.2rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid currentColor;
  white-space: nowrap;
}

.badge-pending        { color: #92400e; background: #fef3c7; }
.badge-in-review      { color: var(--secondary-container); background: var(--surface-container-highest); }
.badge-approved       { color: #15803d; background: #dcfce7; }
.badge-rejected       { color: #b91c1c; background: #fee2e2; }
.badge-info-requested { color: #7c3aed; background: #ede9fe; }
.badge-converted      { color: #0f766e; background: #ccfbf1; }
.badge-unknown        { color: var(--muted); background: var(--surface-container-high); }
</style>
