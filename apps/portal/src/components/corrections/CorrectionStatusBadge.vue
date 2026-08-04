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

function statusLabel(status: CorrectionStatusValue): string {
  switch (status) {
    case 'PENDING':           return 'Pending';
    case 'IN_REVIEW':        return 'In Review';
    case 'APPROVED':         return 'Approved';
    case 'REJECTED':         return 'Rejected';
    case 'INFO_REQUESTED':   return 'Info Requested';
    case 'CONVERTED_TO_DRAFT': return 'Converted to Draft';
    default:                  return 'Unknown';
  }
}
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
.badge-in-review      { color: #ec6a06; background: #2d3449; }
.badge-approved       { color: #15803d; background: #dcfce7; }
.badge-rejected       { color: #b91c1c; background: #fee2e2; }
.badge-info-requested { color: #7c3aed; background: #ede9fe; }
.badge-converted      { color: #0f766e; background: #ccfbf1; }
.badge-unknown        { color: #97a2c0; background: #222a3d; }
</style>
