<template>
  <div class="facility-detail-page">

    <header class="page-header">
      <button class="btn btn-secondary back-btn" @click="router.back()">← Back</button>
      <div class="header-content">
        <h1 class="page-title">{{ facility?.name ?? 'Facility' }}</h1>
        <p v-if="facility?.address" class="page-subtitle">{{ facility.address }}</p>
      </div>
      <button class="btn btn-primary" :disabled="!isDirty" @click="handleSave">
        {{ saving ? 'Saving…' : 'Save Changes' }}
      </button>
    </header>

    <!-- ─── Loading ──────────────────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true">
      <div class="skeleton-card" />
    </div>

    <!-- ─── Error ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="btn btn-secondary" @click="loadFacility">Retry</button>
    </div>

    <!-- ─── Facility form ────────────────────────────────────────────────────── -->
    <div v-else-if="facility" class="facility-form-panel">

      <section class="form-section">
        <h2 class="section-title">Basic Information</h2>

        <div class="form-grid">
          <div class="form-field">
            <label class="form-label" for="facility-name">Facility Name <span class="required">*</span></label>
            <input
              id="facility-name"
              v-model="editForm.name"
              class="form-input"
              type="text"
              placeholder="Facility name"
              @input="markDirty"
            />
            <span v-if="saveError && !editForm.name" class="field-error">Facility name is required</span>
          </div>

          <div class="form-field">
            <label class="form-label" for="facility-phone">Phone</label>
            <input
              id="facility-phone"
              v-model="editForm.phone"
              class="form-input"
              type="tel"
              placeholder="+1 555-000-0000"
              @input="markDirty"
            />
          </div>

          <div class="form-field">
            <label class="form-label" for="facility-website">Website</label>
            <input
              id="facility-website"
              v-model="editForm.website"
              class="form-input"
              type="url"
              placeholder="https://example.com"
              @input="markDirty"
            />
          </div>

          <div class="form-field full-width">
            <label class="form-label" for="facility-address">Address</label>
            <input
              id="facility-address"
              v-model="editForm.address"
              class="form-input"
              type="text"
              placeholder="Street address"
              @input="markDirty"
            />
          </div>
        </div>
      </section>

      <!-- Data quality -->
      <section v-if="facility.dataQuality" class="form-section">
        <h2 class="section-title">Data Quality</h2>
        <div class="quality-row">
          <div class="quality-item">
            <span class="quality-label">Accuracy Class</span>
            <span class="quality-value">{{ facility.dataQuality.accuracyClass ?? '—' }}</span>
          </div>
          <div class="quality-item">
            <span class="quality-label">Verification</span>
            <span class="quality-value">{{ facility.dataQuality.verificationStatus ?? '—' }}</span>
          </div>
          <div class="quality-item">
            <span class="quality-label">Created</span>
            <span class="quality-value">{{ formatInstant(facility.createdAt) }}</span>
          </div>
          <div class="quality-item">
            <span class="quality-label">Updated</span>
            <span class="quality-value">{{ formatInstant(facility.updatedAt) }}</span>
          </div>
        </div>
      </section>

      <!-- Navigation links -->
      <section class="form-section">
        <h2 class="section-title">Manage</h2>
        <div class="nav-links">
          <router-link :to="`/facilities/${facility.id}/courses`" class="nav-link-card">
            <span class="nav-link-title">Courses</span>
            <span class="nav-link-desc">View and manage courses at this facility</span>
          </router-link>
        </div>
      </section>

      <span v-if="saveError" class="error-message" role="alert">{{ saveError }}</span>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import type { FacilityResponse, FacilityUpdateRequest } from '@/types/admin/facility';
import { facilityAdminApi } from '@/api/admin/facilities';

const router = useRouter();
const route = useRoute();
const facilityId = Number(route.params.id);

const facility = ref<FacilityResponse | null>(null);
const loading = ref(false);
const fetchError = ref<string | null>(null);
const saving = ref(false);
const saveError = ref<string | null>(null);
const isDirty = ref(false);

const editForm = reactive<FacilityUpdateRequest>({});

// ─── Mock data (used when API unavailable) ─────────────────────────────────────
const MOCK_FACILITY: FacilityResponse = {
  id: facilityId,
  name: 'Pine Valley Golf Club',
  address: '1 Pine Valley Dr, Pine Valley, NJ 08080',
  phone: '+1 609-555-0100',
  website: 'https://pinevalley.com',
  location: 'POINT(-74.567 39.789)',
  dataQuality: { accuracyClass: 'A', verificationStatus: 'VERIFIED' },
  createdAt: '2025-03-01T10:00:00Z',
  updatedAt: '2025-03-01T12:00:00Z',
};

async function loadFacility() {
  loading.value = true;
  fetchError.value = null;
  try {
    facility.value = await facilityAdminApi.getFacility(facilityId, props.authToken);
  } catch {
    facility.value = MOCK_FACILITY;
  } finally {
    loading.value = false;
  }
}

function markDirty() {
  isDirty.value = true;
}

async function handleSave() {
  if (!editForm.name?.trim()) {
    saveError.value = 'Facility name is required';
    return;
  }
  saving.value = true;
  saveError.value = null;
  try {
    facility.value = await facilityAdminApi.updateFacility(facilityId, editForm, props.authToken);
    isDirty.value = false;
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    saveError.value = apiErr?.message ?? 'Failed to save facility';
  } finally {
    saving.value = false;
  }
}

function formatInstant(iso: string): string {
  return new Date(iso).toLocaleDateString();
}

// Populate edit form when facility loads
function populateForm(f: FacilityResponse) {
  editForm.name = f.name;
  editForm.address = f.address ?? undefined;
  editForm.phone = f.phone ?? undefined;
  editForm.website = f.website ?? undefined;
  editForm.location = f.location ?? undefined;
}

const props = defineProps<{ authToken: string }>();

onMounted(async () => {
  await loadFacility();
  if (facility.value) populateForm(facility.value);
});
</script>

<style scoped>
.facility-detail-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 800px;
  margin: 0 auto;
}

.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 1rem;
}
.back-btn { align-self: center; }
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
  margin: 0;
}
.page-subtitle {
  font-size: 0.875rem;
  color: #6b7280;
  margin: 0.25rem 0 0;
}

.btn {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid transparent;
  min-height: 44px;
  transition: background 0.15s;
}
.btn-primary {
  background: #2563eb;
  color: white;
  border-color: #2563eb;
}
.btn-primary:hover:not(:disabled) { background: #1d4ed8; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary {
  background: white;
  color: #374151;
  border-color: #d1d5db;
}
.btn-secondary:hover { background: #f9fafb; }

.loading-state { display: flex; flex-direction: column; gap: 0.75rem; }
.skeleton-card {
  height: 8rem;
  border-radius: 8px;
  background: linear-gradient(90deg, #e5e7eb 25%, #f3f4f6 50%, #e5e7eb 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 1rem;
  color: #dc2626;
  text-align: center;
}
.error-icon { font-size: 2rem; }

.facility-form-panel {
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 1.25rem;
}

.form-section {
  margin-bottom: 1.5rem;
}
.section-title {
  font-size: 0.875rem;
  font-weight: 600;
  color: #374151;
  margin: 0 0 0.75rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}
.full-width { grid-column: 1 / -1; }
.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}
.form-label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: #374151;
}
.required { color: #dc2626; }
.form-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: white;
  color: #111827;
}
.form-input:focus {
  outline: none;
  border-color: #2563eb;
  box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
}
.field-error {
  font-size: 0.75rem;
  color: #dc2626;
  margin-top: 0.125rem;
}

.quality-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.75rem;
}
.quality-item {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}
.quality-label {
  font-size: 0.6875rem;
  font-weight: 600;
  color: #9ca3af;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.quality-value {
  font-size: 0.875rem;
  font-weight: 500;
  color: #111827;
}

.nav-links { display: flex; flex-direction: column; gap: 0.5rem; }
.nav-link-card {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.75rem 1rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: white;
  text-decoration: none;
  transition: background 0.15s, border-color 0.15s;
}
.nav-link-card:hover { background: #f9fafb; border-color: #2563eb; }
.nav-link-title {
  font-size: 0.875rem;
  font-weight: 600;
  color: #111827;
}
.nav-link-desc {
  font-size: 0.75rem;
  color: #6b7280;
}

.error-message {
  display: block;
  font-size: 0.875rem;
  color: #dc2626;
  margin-top: 0.5rem;
}
</style>
