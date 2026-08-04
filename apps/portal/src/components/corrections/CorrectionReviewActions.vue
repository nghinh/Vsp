<template>
  <section class="correction-review-actions" aria-label="Review actions">
    <h3 class="section-title">Review Actions</h3>

    <!-- Current status indicator -->
    <div class="current-status">
      <span class="status-label">Current Status:</span>
      <CorrectionStatusBadge :status="currentStatus" />
    </div>

    <!-- Action buttons -->
    <div class="action-buttons" role="group" aria-label="Review actions">
      <button
        class="action-btn approve-btn"
        @click="showApproveDialog = true"
        :disabled="actionLoading"
      >
        <span aria-hidden="true">✅</span>
        Approve
      </button>

      <button
        class="action-btn reject-btn"
        @click="showRejectDialog = true"
        :disabled="actionLoading"
      >
        <span aria-hidden="true">❌</span>
        Reject
      </button>

      <button
        class="action-btn request-info-btn"
        @click="showRequestInfoDialog = true"
        :disabled="actionLoading"
      >
        <span aria-hidden="true">💬</span>
        Request Info
      </button>

      <button
        class="action-btn convert-btn"
        @click="showConvertDialog = true"
        :disabled="actionLoading"
      >
        <span aria-hidden="true">📝</span>
        Convert to Draft
      </button>
    </div>

    <!-- Global error -->
    <div v-if="globalError" class="action-error" role="alert">
      <span>⚠</span> {{ globalError }}
    </div>

    <!-- ─── Approve Dialog ─────────────────────────────────────────── -->
    <CorrectionApproveDialog
      v-if="showApproveDialog"
      title="Approve Correction"
      message="Confirm that this correction is valid and should be applied. An audit entry will be created."
      confirm-label="Approve"
      :loading="actionLoading"
      @confirm="handleApprove"
      @cancel="showApproveDialog = false"
    />

    <!-- ─── Reject Dialog ─────────────────────────────────────────── -->
    <CorrectionRejectDialog
      v-if="showRejectDialog"
      :loading="actionLoading"
      @confirm="handleReject"
      @cancel="showRejectDialog = false"
    />

    <!-- ─── Request Info Dialog ──────────────────────────────────── -->
    <CorrectionRequestInfoDialog
      v-if="showRequestInfoDialog"
      :loading="actionLoading"
      @confirm="handleRequestInfo"
      @cancel="showRequestInfoDialog = false"
    />

    <!-- ─── Convert to Draft Dialog ──────────────────────────────── -->
    <CorrectionConvertToDraftDialog
      v-if="showConvertDialog"
      :loading="actionLoading"
      @confirm="handleConvertToDraft"
      @cancel="showConvertDialog = false"
    />
  </section>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { CorrectionStatusValue, CorrectionReviewActionValue } from '@/types/correction';
import { correctionApi } from '@/api/correction';
import CorrectionStatusBadge from './CorrectionStatusBadge.vue';
import CorrectionApproveDialog from './CorrectionApproveDialog.vue';
import CorrectionRejectDialog from './CorrectionRejectDialog.vue';
import CorrectionRequestInfoDialog from './CorrectionRequestInfoDialog.vue';
import CorrectionConvertToDraftDialog from './CorrectionConvertToDraftDialog.vue';

const props = defineProps<{
  correctionId: number;
  currentStatus: CorrectionStatusValue;
  authToken: string;
}>();

const emit = defineEmits<{
  (e: 'reviewed', action: CorrectionReviewActionValue): void;
  (e: 'error', message: string): void;
}>();

// Dialog visibility
const showApproveDialog = ref(false);
const showRejectDialog = ref(false);
const showRequestInfoDialog = ref(false);
const showConvertDialog = ref(false);

// Loading and error state
const actionLoading = ref(false);
const globalError = ref<string | null>(null);

async function submitAction(action: CorrectionReviewActionValue, reason = '', note = '') {
  actionLoading.value = true;
  globalError.value = null;
  try {
    await correctionApi.review(props.authToken, props.correctionId, {
      action,
      reason: reason || undefined,
      note: note || undefined,
    });
    emit('reviewed', action);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    const msg = apiErr?.message ?? 'Review action failed. Please try again.';
    globalError.value = msg;
    emit('error', msg);
  } finally {
    actionLoading.value = false;
    // Close all dialogs
    showApproveDialog.value = false;
    showRejectDialog.value = false;
    showRequestInfoDialog.value = false;
    showConvertDialog.value = false;
  }
}

function handleApprove(note: string) {
  submitAction('APPROVE', '', note);
}

function handleReject(reason: string, note: string) {
  submitAction('REJECT', reason, note);
}

function handleRequestInfo(message: string, note: string) {
  submitAction('REQUEST_INFO', message, note);
}

function handleConvertToDraft(note: string) {
  submitAction('CONVERT_TO_DRAFT', '', note);
}
</script>

<style scoped>
.correction-review-actions {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.section-title {
  font-size: 0.9375rem;
  font-weight: 700;
  color: #111827;
  margin: 0;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e5e7eb;
}

/* Current status */
.current-status {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.625rem 0.875rem;
  background: #f9fafb;
  border-radius: 6px;
  border: 1px solid #e5e7eb;
}

.status-label {
  font-size: 0.8125rem;
  color: #6b7280;
  font-weight: 500;
}

/* Action buttons */
.action-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
}

.action-btn {
  flex: 1;
  min-width: 120px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  padding: 0.625rem 1rem;
  border-radius: 8px;
  border: 1px solid;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  min-height: 48px;
  transition: background 0.15s;
}
.action-btn:disabled { opacity: 0.5; cursor: not-allowed; }

.approve-btn {
  background: #f0fdf4;
  border-color: #86efac;
  color: #15803d;
}
.approve-btn:hover:not(:disabled) { background: #dcfce7; }

.reject-btn {
  background: #fef2f2;
  border-color: #fca5a5;
  color: #b91c1c;
}
.reject-btn:hover:not(:disabled) { background: #fee2e2; }

.request-info-btn {
  background: #faf5ff;
  border-color: #e9d5ff;
  color: #7c3aed;
}
.request-info-btn:hover:not(:disabled) { background: #ede9fe; }

.convert-btn {
  background: #f0fdfa;
  border-color: #99f6e4;
  color: #0f766e;
}
.convert-btn:hover:not(:disabled) { background: #ccfbf1; }

/* Error */
.action-error {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem;
  background: #fef2f2;
  border: 1px solid #fca5a5;
  border-radius: 6px;
  font-size: 0.875rem;
  color: #991b1b;
}
</style>
