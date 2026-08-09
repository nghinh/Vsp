<template>
  <div class="market-page">

    <!-- ─── Header ──────────────────────────────────────────────────────── -->
    <header class="page-header">
      <div class="header-content">
        <div class="eyebrow">GolfOps Portal</div>
        <h1 class="page-title">Thị trường &amp; Tích hợp</h1>
        <p class="page-subtitle">
          Quản lý cấu hình vùng lãnh thổ và dịch vụ thương mại tích hợp.
        </p>
      </div>
      <div class="global-sync" role="status">
        <span class="material-symbols-outlined">cloud_done</span>
        <span>Đồng bộ toàn cục đang bật</span>
      </div>
    </header>

    <div class="market-layout">

      <!-- ─── Territories list ──────────────────────────────────────────── -->
      <aside class="territories" aria-label="Vùng lãnh thổ">
        <div class="territories-head">
          <span class="material-symbols-outlined">flag</span>
          <span>Vùng lãnh thổ</span>
        </div>

        <div v-if="marketsLoading" class="loading-state">
          <div v-for="i in 3" :key="i" class="skeleton-row" />
        </div>
        <div v-else-if="marketsError" class="error-state" role="alert">
          <span>{{ marketsError }}</span>
          <button class="btn btn-secondary" @click="loadMarkets">Thử lại</button>
        </div>
        <div v-else-if="markets.length === 0" class="empty-state">
          <p>Chưa có thị trường nào.</p>
        </div>
        <ul v-else class="territory-list" role="list">
          <li
            v-for="m in markets"
            :key="m.marketId"
            class="territory"
            :class="{ selected: m.marketId === selectedId }"
            role="button"
            tabindex="0"
            @click="selectMarket(m.marketId)"
            @keydown.enter="selectMarket(m.marketId)"
            @keydown.space.prevent="selectMarket(m.marketId)"
          >
            <span class="material-symbols-outlined territory-flag">flag</span>
            <span class="territory-name">{{ m.name }}</span>
            <span class="status-badge" :class="m.active ? 'badge-active' : 'badge-draft'">
              {{ m.active ? 'Active' : 'Bản nháp' }}
            </span>
          </li>
        </ul>
      </aside>

      <!-- ─── Detail panel ──────────────────────────────────────────────── -->
      <section class="detail-panel">

        <div v-if="configLoading" class="loading-state">
          <div class="skeleton-block" />
        </div>
        <div v-else-if="!selectedId" class="empty-state large">
          <span class="material-symbols-outlined">public</span>
          <p>Chọn một vùng lãnh thổ để xem cấu hình.</p>
        </div>

        <template v-else>
          <div class="panel-head">
            <div>
              <h2 class="panel-title">
                <span class="material-symbols-outlined">security</span>
                Ranh giới thương mại
              </h2>
              <p class="panel-hint">
                Tách biệt Core GPS (Lĩnh vực kỹ thuật) và Commercial (Lĩnh vực thanh toán).
              </p>
            </div>
          </div>

          <!-- Distribution-blocked banner -->
          <div v-if="distributionBlocked" class="blocked-banner" role="alert">
            <span class="material-symbols-outlined">block</span>
            <div>
              <strong>Chặn phân phối</strong>
              <p>
                Việc phát hành bị hạn chế cho tới khi tất cả giấy phép bắt buộc được xác thực cho
                thị trường {{ selectedMarket?.name }}.
              </p>
            </div>
          </div>

          <!-- Tabs -->
          <nav class="tab-nav" role="tablist">
            <button
              v-for="tab in tabs"
              :key="tab.id"
              class="tab-btn"
              :class="{ active: activeTab === tab.id }"
              role="tab"
              :aria-selected="activeTab === tab.id"
              @click="activeTab = tab.id"
            >
              {{ tab.label }}
            </button>
          </nav>

          <!-- ── General settings / localization ── -->
          <div v-if="activeTab === 'general'" class="tab-body">
            <div class="section-title-row">
              <span class="material-symbols-outlined">language</span>
              <span>Địa phương hóa</span>
            </div>
            <div class="field-grid">
              <div class="form-field">
                <label class="form-label">NGÔN NGỮ / VÙNG</label>
                <select v-model="marketForm.defaultLanguage" class="form-input">
                  <option value="vi">Vietnamese (VN)</option>
                  <option value="en">English (US)</option>
                  <option value="th">Thai (TH)</option>
                  <option value="ja">Japanese (JP)</option>
                </select>
              </div>
              <div class="form-field">
                <label class="form-label">ĐƠN VỊ KHOẢNG CÁCH</label>
                <select v-model="marketForm.measurementUnit" class="form-input">
                  <option value="METRIC">Mét</option>
                  <option value="IMPERIAL">Yard</option>
                </select>
              </div>
              <div class="form-field">
                <label class="form-label">CURRENCY</label>
                <input v-model="marketForm.currencyCode" class="form-input" type="text" maxlength="3" />
              </div>
              <div class="form-field">
                <label class="form-label">TIMEZONE</label>
                <input v-model="marketForm.timezone" class="form-input" type="text" />
              </div>
              <div class="form-field">
                <label class="form-label">ĐỊNH DẠNG NGÀY</label>
                <input v-model="marketForm.dateFormat" class="form-input" type="text" />
              </div>
              <div class="form-field">
                <label class="form-label">TRẠNG THÁI</label>
                <label class="toggle">
                  <input v-model="marketForm.active" type="checkbox" />
                  <span>{{ marketForm.active ? 'Active' : 'Bản nháp' }}</span>
                </label>
              </div>
            </div>

            <div v-if="configResponse" class="resolved-note">
              Giữ nguyên mặc định Việt Nam khi bỏ trống — retention:
              <strong>{{ configResponse.retentionPolicyDays }} ngày</strong>, locale mặc định
              <strong>{{ configResponse.locale }}</strong>.
            </div>

            <div class="panel-actions">
              <button
                class="btn btn-primary"
                :disabled="saving"
                @click="saveMarket"
              >
                {{ saving ? 'Đang lưu…' : 'Lưu cấu hình vùng' }}
              </button>
              <span v-if="saveMessage" class="save-message">{{ saveMessage }}</span>
            </div>
          </div>

          <!-- ── Commercial boundaries ── -->
          <div v-else-if="activeTab === 'commercial'" class="tab-body">
            <div class="section-title-row">
              <span class="material-symbols-outlined">analytics</span>
              <span>Tách bạch trách nhiệm</span>
            </div>
            <p class="panel-hint">
              Core GPS Rounds tách biệt khỏi Commercial Services. Việc phân phối gói dữ liệu cần
              phê duyệt pháp lý độc lập.
            </p>
            <div class="boundary-list">
              <label class="boundary-row">
                <div>
                  <strong>Tách hành vi GPS</strong>
                  <small>Cho phép thị trường tách xử lý GPS khỏi lõi.</small>
                </div>
                <input v-model="configForm.forkGpsBehavior" type="checkbox" class="switch" />
              </label>
              <label class="boundary-row">
                <div>
                  <strong>Tách hành vi tính điểm</strong>
                  <small>Cho phép thị trường tách xử lý điểm số khỏi lõi.</small>
                </div>
                <input v-model="configForm.forkScoreBehavior" type="checkbox" class="switch" />
              </label>
              <label class="boundary-row">
                <div>
                  <strong>Phân phối lại cần giấy phép</strong>
                  <small>Bắt buộc xác thực giấy phép trước khi phát hành gói.</small>
                </div>
                <input v-model="configForm.redistributionRequiresLicense" type="checkbox" class="switch" />
              </label>
            </div>
            <div class="panel-actions">
              <button class="btn btn-primary" :disabled="saving" @click="saveConfig">
                {{ saving ? 'Đang lưu…' : 'Lưu ranh giới' }}
              </button>
              <span v-if="saveMessage" class="save-message">{{ saveMessage }}</span>
            </div>
          </div>

          <!-- ── Compliance & licenses ── -->
          <div v-else-if="activeTab === 'compliance'" class="tab-body">
            <div class="section-title-row">
              <span class="material-symbols-outlined">verified_user</span>
              <span>Danh mục kiểm tra trước công bố</span>
            </div>

            <ul class="checklist">
              <li class="check-row ok">
                <span class="material-symbols-outlined">check_circle</span>
                <span>Chính sách quyền riêng tư</span>
                <span class="check-tag">v2.4.1</span>
              </li>
              <li class="check-row" :class="redistributionOk ? 'ok' : 'fail'">
                <span class="material-symbols-outlined">
                  {{ redistributionOk ? 'check_circle' : 'error' }}
                </span>
                <span>Giấy phép phân phối lại</span>
                <button
                  v-if="!redistributionOk"
                  class="btn-link fix"
                  @click="validateRedistribution"
                >
                  {{ validating ? 'ĐANG KIỂM TRA…' : 'SỬA NGAY' }}
                </button>
                <span v-else class="check-tag ok-tag">Đã kiểm tra</span>
              </li>
              <li class="check-row ok">
                <span class="material-symbols-outlined">check_circle</span>
                <span>Hệ thống quản lý đồng ý</span>
                <span class="check-tag ok-tag">Đang hoạt động</span>
              </li>
            </ul>

            <div v-if="validationErrors.length" class="validation-errors" role="alert">
              <p v-for="(err, i) in validationErrors" :key="i" class="validation-error">
                <span class="material-symbols-outlined">warning</span>
                <span>[{{ err.code }}] {{ err.message }}</span>
              </p>
            </div>

            <!-- Licenses table -->
            <div class="section-title-row spaced">
              <span class="material-symbols-outlined">receipt_long</span>
              <span>Giấy phép dữ liệu</span>
              <button class="btn btn-secondary small" @click="showLicenseForm = !showLicenseForm">
                + Thêm giấy phép
              </button>
            </div>

            <div v-if="showLicenseForm" class="license-form">
              <div class="field-grid">
                <div class="form-field">
                  <label class="form-label">Tên</label>
                  <input v-model="licenseForm.name" class="form-input" type="text" placeholder="CC BY 4.0" />
                </div>
                <div class="form-field">
                  <label class="form-label">SPDX ID</label>
                  <input v-model="licenseForm.spdxId" class="form-input" type="text" placeholder="CC-BY-4.0" />
                </div>
                <div class="form-field">
                  <label class="form-label">Bên được cấp phép</label>
                  <input v-model="licenseForm.licensee" class="form-input" type="text" />
                </div>
                <div class="form-field">
                  <label class="form-label">Redistribution markets (phân tách bằng dấu phẩy)</label>
                  <input v-model="licenseMarketsText" class="form-input" type="text" placeholder="VN, TH" />
                </div>
              </div>
              <span v-if="licenseError" class="field-error">{{ licenseError }}</span>
              <div class="panel-actions">
                <button class="btn btn-primary" :disabled="licenseSaving" @click="createLicense">
                  {{ licenseSaving ? 'Đang tạo…' : 'Tạo giấy phép' }}
                </button>
                <button class="btn btn-secondary" @click="showLicenseForm = false">Hủy</button>
              </div>
            </div>

            <div v-if="licensesLoading" class="loading-state">
              <div class="skeleton-row" />
            </div>
            <div v-else-if="licensesError" class="empty-state" role="alert">
              <p>Không tải được danh sách giấy phép: {{ licensesError }}</p>
              <button type="button" class="btn-secondary" @click="loadLicenses">Thử lại</button>
            </div>
            <div v-else-if="licenses.length === 0" class="empty-state">
              <p>Chưa có giấy phép dữ liệu.</p>
            </div>
            <div v-else class="data-table">
              <table>
                <thead>
                  <tr>
                    <th>Tên</th>
                    <th>SPDX</th>
                    <th>Thị trường phát hành</th>
                    <th>Hết hạn</th>
                    <th>Trạng thái</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="lic in licenses" :key="lic.licenseId">
                    <td>{{ lic.name }}</td>
                    <td><code>{{ lic.spdxId }}</code></td>
                    <td>
                      <span
                        v-for="mk in lic.redistributionMarkets"
                        :key="mk"
                        class="market-chip"
                        :class="{ current: mk === selectedId }"
                      >{{ mk }}</span>
                    </td>
                    <td>{{ lic.expiresAt ? formatDate(lic.expiresAt) : 'Không giới hạn' }}</td>
                    <td>
                      <span class="status-badge" :class="lic.valid ? 'badge-active' : 'badge-cancelled'">
                        {{ lic.valid ? 'Valid' : 'Hết hạn' }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </template>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { formatDay } from '@/lib/datetime';
import { marketApi } from '@/api/market';
import type {
  Market,
  MarketConfig,
  MarketConfigResponse,
  DataLicense,
  LicenseValidationError,
} from '@/types/market';

const props = defineProps<{ authToken: string }>();

const tabs = [
  { id: 'general', label: 'Cài đặt chung' },
  { id: 'commercial', label: 'Ranh giới thương mại' },
  { id: 'compliance', label: 'Tuân thủ & Giấy phép' },
];

// ─── Markets ────────────────────────────────────────────────────────────────
const markets = ref<Market[]>([]);
const marketsLoading = ref(false);
const marketsError = ref<string | null>(null);
const selectedId = ref<string>('');
const activeTab = ref('general');

// ─── Selected market + config ─────────────────────────────────────────────────
const configResponse = ref<MarketConfigResponse | null>(null);
const configLoading = ref(false);
const marketForm = ref<Market>(emptyMarket());
const configForm = ref<MarketConfig>({ marketId: '' });

// ─── Licenses ─────────────────────────────────────────────────────────────────
const licenses = ref<DataLicense[]>([]);
const licensesLoading = ref(false);
/// Why the list is empty, when it is empty because something broke.
const licensesError = ref<string | null>(null);
const showLicenseForm = ref(false);
const licenseForm = ref({ name: '', spdxId: '', licensee: '' });
const licenseMarketsText = ref('');
const licenseError = ref<string | null>(null);
const licenseSaving = ref(false);

// ─── Validation ───────────────────────────────────────────────────────────────
const validating = ref(false);
const validationErrors = ref<LicenseValidationError[]>([]);
const redistributionValidated = ref(false);

// ─── Save state ───────────────────────────────────────────────────────────────
const saving = ref(false);
const saveMessage = ref<string | null>(null);

function emptyMarket(): Market {
  return {
    marketId: '',
    name: '',
    currencyCode: '',
    dateFormat: '',
    measurementUnit: 'METRIC',
    timezone: '',
    defaultLanguage: 'vi',
    active: true,
  };
}

// ─── Computed ─────────────────────────────────────────────────────────────────
const selectedMarket = computed(() =>
  markets.value.find((m) => m.marketId === selectedId.value) ?? null
);

/** True when redistribution licensing is satisfied (or not required). */
const redistributionOk = computed(() => {
  if (!configForm.value.redistributionRequiresLicense) return true;
  return redistributionValidated.value && validationErrors.value.length === 0;
});

const distributionBlocked = computed(
  () => !!configForm.value.redistributionRequiresLicense && !redistributionOk.value
);

// ─── Load ────────────────────────────────────────────────────────────────────
async function loadMarkets() {
  marketsLoading.value = true;
  marketsError.value = null;
  try {
    const res = await marketApi.listMarkets(props.authToken);
    markets.value = res.content ?? [];
    if (markets.value.length && !selectedId.value) {
      await selectMarket(markets.value[0].marketId);
    }
  } catch (e: unknown) {
    marketsError.value = (e as { message?: string })?.message ?? 'Không tải được danh sách thị trường';
  } finally {
    marketsLoading.value = false;
  }
}

async function selectMarket(marketId: string) {
  selectedId.value = marketId;
  saveMessage.value = null;
  validationErrors.value = [];
  redistributionValidated.value = false;
  configLoading.value = true;
  try {
    const [market, config] = await Promise.all([
      marketApi.getMarket(props.authToken, marketId),
      marketApi.getMarketConfig(props.authToken, marketId).catch(() => null),
    ]);
    marketForm.value = { ...emptyMarket(), ...market };
    configResponse.value = config;
    configForm.value = {
      marketId,
      forkGpsBehavior: config?.forkGpsBehavior ?? false,
      forkScoreBehavior: config?.forkScoreBehavior ?? false,
      redistributionRequiresLicense: config?.redistributionRequiresLicense ?? false,
    };
  } catch (e: unknown) {
    marketsError.value = (e as { message?: string })?.message ?? 'Không tải được cấu hình thị trường';
  } finally {
    configLoading.value = false;
  }
}

async function loadLicenses() {
  licensesLoading.value = true;
  try {
    licenses.value = await marketApi.listLicenses(props.authToken);
    licensesError.value = null;
  } catch (e: unknown) {
    // Emptying the list on failure made a broken request and a genuinely
    // empty licence list look identical, and the second one is the answer an
    // operator would act on.
    const apiErr = e as { message?: string };
    licensesError.value = apiErr?.message ?? 'Không tải được giấy phép';
  } finally {
    licensesLoading.value = false;
  }
}

// ─── Save ────────────────────────────────────────────────────────────────────
async function saveMarket() {
  if (!selectedId.value) return;
  saving.value = true;
  saveMessage.value = null;
  try {
    const updated = await marketApi.upsertMarket(props.authToken, selectedId.value, {
      ...marketForm.value,
      marketId: selectedId.value,
    });
    const idx = markets.value.findIndex((m) => m.marketId === selectedId.value);
    if (idx >= 0) markets.value[idx] = updated;
    saveMessage.value = 'Đã lưu cấu hình vùng.';
  } catch (e: unknown) {
    saveMessage.value = (e as { message?: string })?.message ?? 'Lưu thất bại';
  } finally {
    saving.value = false;
  }
}

async function saveConfig() {
  if (!selectedId.value) return;
  saving.value = true;
  saveMessage.value = null;
  try {
    await marketApi.upsertMarketConfig(props.authToken, selectedId.value, {
      ...configForm.value,
      marketId: selectedId.value,
    });
    saveMessage.value = 'Đã lưu ranh giới thương mại.';
    // Requiring a license invalidates any prior validation result.
    redistributionValidated.value = false;
  } catch (e: unknown) {
    saveMessage.value = (e as { message?: string })?.message ?? 'Lưu thất bại';
  } finally {
    saving.value = false;
  }
}

// ─── Licenses ─────────────────────────────────────────────────────────────────
async function createLicense() {
  licenseError.value = null;
  const redistributionMarkets = licenseMarketsText.value
    .split(',')
    .map((s) => s.trim().toUpperCase())
    .filter((s) => s.length > 0);
  if (!licenseForm.value.name.trim() || !licenseForm.value.spdxId.trim()) {
    licenseError.value = 'Cần nhập tên và SPDX ID.';
    return;
  }
  if (redistributionMarkets.length === 0) {
    licenseError.value = 'Cần ít nhất một thị trường phát hành.';
    return;
  }
  licenseSaving.value = true;
  try {
    await marketApi.createLicense(props.authToken, {
      name: licenseForm.value.name.trim(),
      spdxId: licenseForm.value.spdxId.trim(),
      licensee: licenseForm.value.licensee.trim() || undefined,
      redistributionMarkets,
    });
    licenseForm.value = { name: '', spdxId: '', licensee: '' };
    licenseMarketsText.value = '';
    showLicenseForm.value = false;
    await loadLicenses();
  } catch (e: unknown) {
    licenseError.value = (e as { message?: string })?.message ?? 'Tạo giấy phép thất bại';
  } finally {
    licenseSaving.value = false;
  }
}

async function validateRedistribution() {
  if (!selectedId.value) return;
  validating.value = true;
  validationErrors.value = [];
  try {
    const result = await marketApi.validateRedistribution(props.authToken, {
      targetMarket: selectedId.value,
      licenses: licenses.value.map((l) => ({ spdxId: l.spdxId, licenseId: l.licenseId })),
    });
    validationErrors.value = result.errors ?? [];
    redistributionValidated.value = result.isValid;
  } catch (e: unknown) {
    validationErrors.value = [
      {
        code: 'LICENSE_NOT_FOUND',
        message: (e as { message?: string })?.message ?? 'Xác thực thất bại',
      },
    ];
    redistributionValidated.value = false;
  } finally {
    validating.value = false;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
function formatDate(iso?: string | null): string {
  if (!iso) return '—';
  return formatDay(iso);
}

// ─── Init ─────────────────────────────────────────────────────────────────────
loadMarkets();
loadLicenses();
</script>

<style scoped>
.market-page {
  font-family: 'Fira Sans', system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 1100px;
  margin: 0 auto;
  color: #dae2fd;
}

/* Header */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
  border-bottom: 1px solid #2d3449;
  padding-bottom: 1rem;
}
.eyebrow {
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: #ffb599;
}
.page-title { font-size: 1.5rem; font-weight: 700; color: #dae2fd; margin: 0.25rem 0 0; }
.page-subtitle { font-size: 0.875rem; color: #97a2c0; margin: 0.25rem 0 0; }
.global-sync {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.8125rem;
  color: #68dba9;
  background: #131b2e;
  border: 1px solid #25a475;
  border-radius: 9999px;
  padding: 0.35rem 0.75rem;
  white-space: nowrap;
}
.global-sync .material-symbols-outlined { font-size: 1.1rem; }

/* Layout */
.market-layout {
  display: grid;
  grid-template-columns: 260px 1fr;
  gap: 1.25rem;
  align-items: start;
}
@media (max-width: 800px) {
  .market-layout { grid-template-columns: 1fr; }
}

/* Territories */
.territories {
  background: #171f33;
  border: 1px solid #2d3449;
  border-radius: 12px;
  padding: 0.75rem;
}
.territories-head {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #97a2c0;
  padding: 0.25rem 0.5rem 0.6rem;
}
.territory-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 0.25rem; }
.territory {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.6rem 0.5rem;
  border-radius: 8px;
  cursor: pointer;
  min-height: 44px;
  border: 1px solid transparent;
}
.territory:hover { background: #222a3d; }
.territory.selected { background: #222a3d; border-color: #f66018; }
.territory-flag { color: #ffb599; font-size: 1.15rem; }
.territory-name { flex: 1; font-size: 0.875rem; font-weight: 500; color: #dae2fd; }

/* Status badges */
.status-badge {
  font-size: 0.625rem;
  font-weight: 700;
  padding: 0.15rem 0.5rem;
  border-radius: 9999px;
  white-space: nowrap;
}
.badge-active { background: #0f2e22; color: #68dba9; }
.badge-draft { background: #222a3d; color: #97a2c0; }
.badge-cancelled { background: #3a1614; color: #ffb4ab; }

/* Detail panel */
.detail-panel {
  background: #171f33;
  border: 1px solid #2d3449;
  border-radius: 12px;
  padding: 1.25rem;
  min-height: 300px;
}
.panel-head { margin-bottom: 1rem; }
.panel-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1.125rem;
  font-weight: 700;
  color: #dae2fd;
  margin: 0;
}
.panel-title .material-symbols-outlined { color: #ffb599; }
.panel-hint { font-size: 0.8125rem; color: #97a2c0; margin: 0.35rem 0 0; }

/* Blocked banner */
.blocked-banner {
  display: flex;
  gap: 0.6rem;
  align-items: flex-start;
  background: #3a1614;
  border: 1px solid #93000a;
  border-radius: 10px;
  padding: 0.75rem 1rem;
  margin-bottom: 1rem;
  color: #ffdad6;
}
.blocked-banner .material-symbols-outlined { color: #ffb4ab; }
.blocked-banner strong { display: block; font-size: 0.875rem; }
.blocked-banner p { margin: 0.2rem 0 0; font-size: 0.8125rem; }

/* Tabs */
.tab-nav {
  display: flex;
  gap: 0.25rem;
  border-bottom: 1px solid #2d3449;
  margin-bottom: 1.25rem;
  overflow-x: auto;
}
.tab-btn {
  padding: 0.6rem 1rem;
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  color: #97a2c0;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
  min-height: 44px;
}
.tab-btn:hover { color: #dae2fd; }
.tab-btn.active { color: #f66018; border-bottom-color: #f66018; }

.tab-body { animation: fadeIn 0.15s ease; }
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

.section-title-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9375rem;
  font-weight: 600;
  color: #c5cde8;
  margin-bottom: 0.75rem;
}
.section-title-row.spaced { margin-top: 1.5rem; }
.section-title-row .material-symbols-outlined { color: #ffb599; font-size: 1.2rem; }

/* Fields */
.field-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 0.85rem;
  margin-bottom: 1rem;
}
.form-field { display: flex; flex-direction: column; gap: 0.35rem; }
.form-label {
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  color: #97a2c0;
}
.form-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #2d3449;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: #131b2e;
  color: #dae2fd;
}
.form-input:focus { outline: none; border-color: #f66018; box-shadow: 0 0 0 3px rgba(246,96,24,0.12); }
.field-error { font-size: 0.75rem; color: #ffb4ab; }

.toggle { display: flex; align-items: center; gap: 0.5rem; min-height: 44px; font-size: 0.875rem; color: #dae2fd; }

.resolved-note {
  font-size: 0.8125rem;
  color: #97a2c0;
  background: #131b2e;
  border: 1px solid #2d3449;
  border-radius: 8px;
  padding: 0.6rem 0.75rem;
  margin-bottom: 1rem;
}
.resolved-note strong { color: #dae2fd; }

/* Commercial boundaries */
.boundary-list { display: flex; flex-direction: column; gap: 0.5rem; margin-bottom: 1rem; }
.boundary-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.75rem 1rem;
  background: #131b2e;
  border: 1px solid #2d3449;
  border-radius: 10px;
  cursor: pointer;
}
.boundary-row strong { display: block; font-size: 0.875rem; color: #dae2fd; }
.boundary-row small { font-size: 0.75rem; color: #97a2c0; }
.switch { width: 20px; height: 20px; accent-color: #f66018; }

/* Checklist */
.checklist { list-style: none; margin: 0 0 1rem; padding: 0; display: flex; flex-direction: column; gap: 0.4rem; }
.check-row {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.6rem 0.85rem;
  background: #131b2e;
  border: 1px solid #2d3449;
  border-radius: 8px;
  font-size: 0.875rem;
}
.check-row span:nth-child(2) { flex: 1; }
.check-row.ok .material-symbols-outlined { color: #68dba9; }
.check-row.fail { border-color: #93000a; }
.check-row.fail .material-symbols-outlined { color: #ffb4ab; }
.check-tag { font-size: 0.6875rem; color: #97a2c0; }
.ok-tag { color: #68dba9; }
.btn-link.fix {
  background: none;
  border: none;
  color: #ffb4ab;
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  cursor: pointer;
}

.validation-errors {
  background: #3a1614;
  border: 1px solid #93000a;
  border-radius: 8px;
  padding: 0.6rem 0.85rem;
  margin-bottom: 1rem;
}
.validation-error {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.8125rem;
  color: #ffdad6;
  margin: 0.15rem 0;
}
.validation-error .material-symbols-outlined { font-size: 1rem; color: #ffb4ab; }

/* License form */
.license-form {
  background: #131b2e;
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 1rem;
  margin-bottom: 1rem;
}

.market-chip {
  display: inline-block;
  font-size: 0.6875rem;
  font-weight: 600;
  padding: 0.1rem 0.4rem;
  margin: 0 0.2rem 0.2rem 0;
  border-radius: 4px;
  background: #222a3d;
  color: #c5cde8;
}
.market-chip.current { background: #4f1700; color: #ffb599; }

/* Buttons */
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
.btn.small { min-height: 34px; padding: 0.3rem 0.7rem; font-size: 0.75rem; margin-left: auto; }
.btn-primary { background: #f66018; color: white; border-color: #f66018; }
.btn-primary:hover:not(:disabled) { background: #ec6a06; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary { background: #131b2e; color: #c5cde8; border-color: #2d3449; }
.btn-secondary:hover:not(:disabled) { background: #222a3d; }

.panel-actions { display: flex; gap: 0.75rem; align-items: center; margin-top: 0.5rem; }
.save-message { font-size: 0.8125rem; color: #68dba9; }

/* Tables */
.data-table { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
th { text-align: left; padding: 0.6rem 0.75rem; background: #131b2e; border-bottom: 1px solid #2d3449; font-weight: 600; color: #c5cde8; white-space: nowrap; }
td { padding: 0.6rem 0.75rem; border-bottom: 1px solid #222a3d; color: #dae2fd; }
td code, th code { font-family: 'Fira Code', ui-monospace, monospace; color: #ffb599; }

/* States */
.loading-state { display: flex; flex-direction: column; gap: 0.5rem; }
.skeleton-row { height: 3rem; border-radius: 8px; background: linear-gradient(90deg,#2d3449 25%,#222a3d 50%,#2d3449 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; }
.skeleton-block { height: 12rem; border-radius: 10px; background: linear-gradient(90deg,#2d3449 25%,#222a3d 50%,#2d3449 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; }
@keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
.error-state { display: flex; flex-direction: column; gap: 0.5rem; padding: 1.5rem; color: #ffb4ab; align-items: center; text-align: center; }
.empty-state { display: flex; flex-direction: column; gap: 0.5rem; padding: 1.5rem; color: #97a2c0; align-items: center; text-align: center; font-size: 0.875rem; }
.empty-state.large { padding: 3rem 1rem; }
.empty-state .material-symbols-outlined { font-size: 2rem; color: #2d3449; }
</style>
