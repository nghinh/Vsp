<template>
  <div class="facilities-page">

    <header class="page-header">
      <div class="header-content">
        <h1 class="page-title">Golf Facilities</h1>
        <p class="page-subtitle">Manage golf facilities and their courses.</p>
      </div>
      <button class="btn btn-primary" @click="showCreateForm = !showCreateForm">
        {{ showCreateForm ? 'Cancel' : '+ New Facility' }}
      </button>
    </header>

    <!-- ─── Create form ─────────────────────────────────────────────────────── -->
    <div v-if="showCreateForm" class="create-form-panel">
      <h2 class="form-title">Create Golf Facility</h2>

      <div class="form-grid">
        <div class="form-field">
          <label class="form-label" for="facility-name">Facility Name <span class="required">*</span></label>
          <input
            id="facility-name"
            v-model="createForm.name"
            class="form-input"
            type="text"
            placeholder="e.g. Pine Valley Golf Club"
            autocomplete="off"
          />
          <span v-if="validationErrors.name" class="field-error">{{ validationErrors.name }}</span>
        </div>

        <div class="form-field">
          <label class="form-label" for="facility-phone">Phone</label>
          <input
            id="facility-phone"
            v-model="createForm.phone"
            class="form-input"
            type="tel"
            placeholder="+1 555-000-0000"
            autocomplete="off"
          />
        </div>

        <div class="form-field">
          <label class="form-label" for="facility-website">Website</label>
          <input
            id="facility-website"
            v-model="createForm.website"
            class="form-input"
            type="url"
            placeholder="https://example.com"
            autocomplete="off"
          />
        </div>

        <div class="form-field full-width">
          <label class="form-label" for="facility-address">Address</label>
          <input
            id="facility-address"
            v-model="createForm.address"
            class="form-input"
            type="text"
            placeholder="Street address"
            autocomplete="off"
          />
        </div>
      </div>

      <div class="form-actions">
        <span v-if="createError" class="error-message" role="alert">{{ createError }}</span>
        <button
          class="btn btn-primary"
          :disabled="creating"
          @click="handleCreate"
        >
          {{ creating ? 'Creating…' : 'Create Facility' }}
        </button>
      </div>
    </div>

    <!-- ─── Loading ──────────────────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true">
      <div v-for="i in 3" :key="i" class="skeleton-card" />
    </div>

    <!-- ─── Error ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="btn btn-secondary" @click="loadFacilities">Retry</button>
    </div>

    <!-- ─── Empty ─────────────────────────────────────────────────────────────── -->
    <div v-else-if="facilities.length === 0 && !showCreateForm" class="empty-state">
      <span class="empty-icon">🏌️</span>
      <p class="empty-title">No facilities yet.</p>
      <p class="empty-subtitle">Add your first golf facility to start managing courses.</p>
      <button class="btn btn-primary" @click="showCreateForm = true">Add First Facility</button>
    </div>

    <!-- ─── Facility list ─────────────────────────────────────────────────────── -->
    <div v-else class="facility-list" role="list">
      <div
        v-for="facility in facilities"
        :key="facility.id"
        class="facility-card"
        role="listitem"
        @click="navigateToFacility(facility.id)"
      >
        <div class="facility-header">
          <span class="facility-name">{{ facility.name }}</span>
          <span v-if="facility.dataQuality" class="quality-badge" :class="qualityClass(facility.dataQuality)">
            {{ facility.dataQuality.accuracyClass ?? '?' }}
          </span>
        </div>

        <p v-if="facility.address" class="facility-address">{{ facility.address }}</p>
        <p v-if="facility.phone" class="facility-phone">{{ facility.phone }}</p>

        <div class="facility-meta">
          <span class="meta-item">Created {{ formatInstant(facility.createdAt) }}</span>
          <span v-if="facility.website" class="meta-item">{{ facility.website }}</span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import type { FacilityResponse, FacilityCreateRequest } from '@/types/admin/facility';
import { facilityAdminApi } from '@/api/admin/facilities';

const router = useRouter();

const facilities = ref<FacilityResponse[]>([]);
const loading = ref(false);
const fetchError = ref<string | null>(null);

// ─── Mock data (used when API unavailable) ─────────────────────────────────────
const MOCK_FACILITIES: FacilityResponse[] = [
  {
    id: 1,
    name: 'Pine Valley Golf Club',
    address: '1 Pine Valley Dr, Pine Valley, NJ 08080',
    phone: '+1 609-555-0100',
    website: 'https://pinevalley.com',
    location: 'POINT(-74.567 39.789)',
    dataQuality: { accuracyClass: 'A', verificationStatus: 'VERIFIED' },
    createdAt: '2025-03-01T10:00:00Z',
    updatedAt: '2025-03-01T10:00:00Z',
  },
  {
    id: 2,
    name: 'Augusta National Golf Club',
    address: '2604 Washington Rd, Augusta, GA 30904',
    phone: '+1 706-555-0101',
    website: 'https://augusta.com',
    location: 'POINT(-82.022 33.503)',
    dataQuality: { accuracyClass: 'A', verificationStatus: 'VERIFIED' },
    createdAt: '2025-02-15T09:00:00Z',
    updatedAt: '2025-02-15T09:00:00Z',
  },
];

// ─── Create form state ─────────────────────────────────────────────────────────
const showCreateForm = ref(false);
const creating = ref(false);
const createError = ref<string | null>(null);
const validationErrors = reactive<Record<string, string>>({});

const createForm = reactive<FacilityCreateRequest>({
  name: '',
  address: '',
  phone: '',
  website: '',
  location: '',
});

// ─── Load ─────────────────────────────────────────────────────────────────────
async function loadFacilities() {
  loading.value = true;
  fetchError.value = null;
  try {
    const data = await facilityAdminApi.listFacilities(props.authToken);
    facilities.value = data;
  } catch {
    // Fallback to mock data when API unavailable
    facilities.value = MOCK_FACILITIES;
  } finally {
    loading.value = false;
  }
}

async function handleCreate() {
  validationErrors.name = createForm.name?.trim() ? '' : 'Facility name is required';
  if (validationErrors.name) return;

  creating.value = true;
  createError.value = null;
  try {
    const facility = await facilityAdminApi.createFacility(createForm, props.authToken);
    showCreateForm.value = false;
    Object.assign(createForm, { name: '', address: '', phone: '', website: '', location: '' });
    router.push(`/facilities/${facility.id}`);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    createError.value = apiErr?.message ?? 'Failed to create facility';
  } finally {
    creating.value = false;
  }
}

function navigateToFacility(id: number) {
  router.push(`/facilities/${id}`);
}

function formatInstant(iso: string): string {
  return new Date(iso).toLocaleDateString();
}

function qualityClass(dq: { accuracyClass: string | null; verificationStatus: string | null }) {
  if (dq.verificationStatus === 'VERIFIED') return 'badge-verified';
  if (dq.verificationStatus === 'PENDING_REVIEW') return 'badge-pending';
  return 'badge-unverified';
}

const props = defineProps<{ authToken: string }>();

onMounted(() => loadFacilities());
</script>

<style scoped>
.facilities-page {
  font-family: "Fira Sans", ui-sans-serif, system-ui, sans-serif;
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
  border-bottom: 1px solid #2d3449;
  padding-bottom: 1rem;
}
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #dae2fd;
  margin: 0;
}
.page-subtitle {
  font-size: 0.875rem;
  color: #97a2c0;
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
  background: #f66018;
  color: white;
  border-color: #f66018;
}
.btn-primary:hover:not(:disabled) { background: #ec6a06; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary {
  background: #171f33;
  color: #c5cde8;
  border-color: #2d3449;
}
.btn-secondary:hover { background: #171f33; }

.create-form-panel {
  background: #171f33;
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 1.25rem;
  margin-bottom: 1.5rem;
}
.form-title {
  font-size: 1rem;
  font-weight: 600;
  color: #dae2fd;
  margin: 0 0 1rem;
}
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  margin-bottom: 1rem;
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
  color: #c5cde8;
}
.required { color: #dc2626; }
.form-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #2d3449;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: #171f33;
  color: #dae2fd;
}
.form-input:focus {
  outline: none;
  border-color: #f66018;
  box-shadow: 0 0 0 3px rgba(246, 96, 24, 0.1);
}
.field-error {
  font-size: 0.75rem;
  color: #dc2626;
  margin-top: 0.125rem;
}
.form-actions {
  display: flex;
  align-items: center;
  gap: 1rem;
  justify-content: flex-end;
}
.error-message {
  font-size: 0.875rem;
  color: #dc2626;
  margin-right: auto;
}

.loading-state { display: flex; flex-direction: column; gap: 0.75rem; }
.skeleton-card {
  height: 5rem;
  border-radius: 8px;
  background: linear-gradient(90deg, #2d3449 25%, #222a3d 50%, #2d3449 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.error-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 1rem;
  color: #97a2c0;
  text-align: center;
}
.error-state { color: #dc2626; }
.empty-icon, .error-icon { font-size: 2rem; }
.empty-title { font-size: 1.125rem; font-weight: 600; margin: 0; }
.empty-subtitle { font-size: 0.875rem; color: #97a2c0; margin: 0; }

.facility-list { display: flex; flex-direction: column; gap: 0.75rem; }
.facility-card {
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 1rem;
  background: #171f33;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
.facility-card:hover {
  background: #171f33;
  border-color: #f66018;
}
.facility-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.35rem;
}
.facility-name {
  font-size: 1rem;
  font-weight: 600;
  color: #dae2fd;
}
.quality-badge {
  font-size: 0.6875rem;
  font-weight: 700;
  padding: 0.15rem 0.5rem;
  border-radius: 9999px;
  border: 1px solid currentColor;
}
.badge-verified { color: #15803d; background: #dcfce7; }
.badge-pending  { color: #92400e; background: #fef3c7; }
.badge-unverified { color: #97a2c0; background: #222a3d; }
.facility-address,
.facility-phone {
  font-size: 0.8125rem;
  color: #97a2c0;
  margin: 0 0 0.25rem;
}
.facility-meta {
  display: flex;
  gap: 1rem;
  font-size: 0.75rem;
  color: #97a2c0;
}
</style>
