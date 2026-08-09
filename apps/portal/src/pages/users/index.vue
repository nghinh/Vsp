<script setup lang="ts">
/**
 * Operators, roles and two-factor authentication.
 *
 * These endpoints govern who can change course data, and until now the only
 * way to grant a role was a SQL statement. That is the kind of gap that gets
 * closed by giving somebody SUPER_ADMIN "temporarily".
 *
 * Two deliberate frictions, because this page hands out authority:
 *
 *   • Revoking a role asks first. Granting does not — an unwanted grant is
 *     undone by a revoke, while an accidental revoke can lock the last
 *     administrator out of the tool they would use to undo it.
 *   • The enrolment secret is shown once, where it is generated, and is never
 *     re-fetched into the list. Anything that renders a TOTP secret next to a
 *     username in a table will eventually be photographed.
 */
import { computed, onMounted, ref } from 'vue';

import { ROLE_NAMES, userAdminApi } from '@/api/admin/users';
import type { AdminAccount, MfaEnrolment, RoleName } from '@/api/admin/users';

const props = defineProps<{ authToken: string }>();

const accounts = ref<AdminAccount[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);
const notice = ref<string | null>(null);
const busyAccountId = ref<number | null>(null);

// ─── Load ───────────────────────────────────────────────────────────────────

async function load() {
  loading.value = true;
  error.value = null;
  try {
    accounts.value = await userAdminApi.listAccounts(props.authToken);
  } catch (e: unknown) {
    const apiErr = e as { message?: string; code?: string };
    // A non-SUPER_ADMIN gets 403 here. Saying so is more useful than "failed".
    error.value =
      apiErr?.code === 'VSP-ERR-AUTH-003' || apiErr?.code === 'FORBIDDEN'
        ? 'Chỉ SUPER_ADMIN mới xem được danh sách người vận hành.'
        : (apiErr?.message ?? 'Không tải được danh sách người vận hành');
  } finally {
    loading.value = false;
  }
}

// ─── Roles ──────────────────────────────────────────────────────────────────

const grantRole = ref<Record<number, RoleName>>({});

function availableRoles(account: AdminAccount): RoleName[] {
  return ROLE_NAMES.filter((r) => !account.roles?.includes(r));
}

async function grant(account: AdminAccount) {
  const role = grantRole.value[account.golferAccountId];
  if (!role) return;
  busyAccountId.value = account.golferAccountId;
  error.value = null;
  try {
    await userAdminApi.grantRole(props.authToken, account.golferAccountId, role);
    notice.value = `Đã cấp quyền ${role}.`;
    delete grantRole.value[account.golferAccountId];
    await load();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không cấp được quyền';
  } finally {
    busyAccountId.value = null;
  }
}

const confirmRevoke = ref<{ accountId: number; role: RoleName } | null>(null);

async function revoke() {
  const target = confirmRevoke.value;
  if (!target) return;
  busyAccountId.value = target.accountId;
  error.value = null;
  try {
    await userAdminApi.revokeRole(props.authToken, target.accountId, target.role);
    notice.value = `Đã thu hồi quyền ${target.role}.`;
    confirmRevoke.value = null;
    await load();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không thu hồi được quyền';
  } finally {
    busyAccountId.value = null;
  }
}

const superAdminCount = computed(
  () => accounts.value.filter((a) => a.roles?.includes('SUPER_ADMIN')).length,
);

/** True when revoking this would leave nobody able to grant it back. */
function isLastSuperAdmin(account: AdminAccount, role: RoleName): boolean {
  return role === 'SUPER_ADMIN' && superAdminCount.value <= 1 && account.roles.includes('SUPER_ADMIN');
}

// ─── MFA ────────────────────────────────────────────────────────────────────

const enrolment = ref<{ accountId: number; data: MfaEnrolment } | null>(null);
const totpCode = ref('');
const mfaError = ref<string | null>(null);

async function beginEnrolment(account: AdminAccount) {
  mfaError.value = null;
  busyAccountId.value = account.golferAccountId;
  try {
    const data = await userAdminApi.beginMfaEnrolment(props.authToken, account.golferAccountId);
    enrolment.value = { accountId: account.golferAccountId, data };
    totpCode.value = '';
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    mfaError.value = apiErr?.message ?? 'Không bắt đầu được đăng ký MFA';
  } finally {
    busyAccountId.value = null;
  }
}

async function confirmEnrolment() {
  const current = enrolment.value;
  if (!current) return;
  mfaError.value = null;
  try {
    await userAdminApi.confirmMfaEnrolment(props.authToken, current.accountId, totpCode.value.trim());
    notice.value = 'Đã bật xác thực hai lớp.';
    enrolment.value = null;
    await load();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    mfaError.value = apiErr?.message ?? 'Mã không đúng hoặc đã hết hiệu lực';
  }
}

async function disableMfa(account: AdminAccount) {
  busyAccountId.value = account.golferAccountId;
  error.value = null;
  try {
    await userAdminApi.disableMfa(props.authToken, account.golferAccountId);
    notice.value = 'Đã tắt xác thực hai lớp.';
    await load();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tắt được xác thực hai lớp';
  } finally {
    busyAccountId.value = null;
  }
}

function fmt(iso?: string): string {
  return iso ? new Date(iso).toLocaleString('vi-VN') : '—';
}

onMounted(load);
</script>

<template>
  <div class="page">
    <header class="page-header">
      <h1 class="page-title">Người vận hành</h1>
      <p class="page-subtitle">
        Cấp và thu hồi quyền, quản lý xác thực hai lớp. Mọi thao tác ở đây đều
        do máy chủ kiểm tra lại — trang này chỉ là giao diện.
      </p>
    </header>

    <p v-if="notice" class="notice" role="status">{{ notice }}</p>
    <p v-if="error" class="error" role="alert">
      {{ error }}
      <button type="button" class="btn-link" @click="load">Thử lại</button>
    </p>

    <section class="card">
      <p v-if="loading" class="muted">Đang tải…</p>
      <p v-else-if="accounts.length === 0" class="muted">Chưa có tài khoản vận hành nào.</p>
      <table v-else class="table">
        <thead>
          <tr>
            <th>Tài khoản</th>
            <th>Quyền</th>
            <th>Xác thực hai lớp</th>
            <th>Cấp thêm quyền</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="a in accounts" :key="a.id">
            <td>
              <strong>#{{ a.golferAccountId }}</strong>
              <p class="muted small">Tạo: {{ fmt(a.createdAt) }}</p>
            </td>

            <td>
              <span v-if="!a.roles?.length" class="muted">—</span>
              <span v-for="r in a.roles" :key="r" class="role-chip">
                {{ r }}
                <button
                  type="button" class="chip-x" :title="`Thu hồi ${r}`"
                  :disabled="busyAccountId === a.golferAccountId"
                  @click="confirmRevoke = { accountId: a.golferAccountId, role: r }"
                >×</button>
              </span>
            </td>

            <td>
              <span :class="a.mfaEnabled ? 'badge-ok' : 'badge-idle'">
                {{ a.mfaEnabled ? 'Đã bật' : 'Chưa bật' }}
              </span>
              <div class="mfa-actions">
                <button
                  v-if="!a.mfaEnabled" type="button" class="btn-link"
                  :disabled="busyAccountId === a.golferAccountId"
                  @click="beginEnrolment(a)"
                >Đăng ký</button>
                <button
                  v-else type="button" class="btn-link danger"
                  :disabled="busyAccountId === a.golferAccountId"
                  @click="disableMfa(a)"
                >Tắt</button>
              </div>
            </td>

            <td>
              <div class="grant-row">
                <select v-model="grantRole[a.golferAccountId]" class="input" :aria-label="`Quyền cấp cho tài khoản ${a.golferAccountId}`">
                  <option :value="undefined">— Chọn quyền —</option>
                  <option v-for="r in availableRoles(a)" :key="r" :value="r">{{ r }}</option>
                </select>
                <button
                  type="button" class="btn-primary small"
                  :disabled="!grantRole[a.golferAccountId] || busyAccountId === a.golferAccountId"
                  @click="grant(a)"
                >Cấp</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </section>

    <!-- ─── Revoke confirmation ──────────────────────────────────────────── -->
    <div v-if="confirmRevoke" class="modal-backdrop">
      <div class="modal" role="dialog" aria-modal="true">
        <h2 class="modal-title">Thu hồi quyền {{ confirmRevoke.role }}?</h2>
        <p class="modal-body">
          Tài khoản #{{ confirmRevoke.accountId }} sẽ mất quyền này ngay lập tức.
        </p>
        <p
          v-if="isLastSuperAdmin(
            accounts.find(a => a.golferAccountId === confirmRevoke!.accountId)!,
            confirmRevoke.role,
          )"
          class="error"
        >
          Đây là SUPER_ADMIN cuối cùng. Thu hồi xong sẽ không còn ai cấp lại được
          quyền này từ trang quản trị.
        </p>
        <div class="actions">
          <button type="button" class="btn-secondary" @click="confirmRevoke = null">Huỷ</button>
          <button type="button" class="btn-danger" @click="revoke">Thu hồi</button>
        </div>
      </div>
    </div>

    <!-- ─── MFA enrolment ────────────────────────────────────────────────── -->
    <div v-if="enrolment" class="modal-backdrop">
      <div class="modal" role="dialog" aria-modal="true">
        <h2 class="modal-title">Đăng ký xác thực hai lớp</h2>
        <p class="modal-body">
          Quét mã hoặc nhập khoá thủ công vào ứng dụng xác thực, rồi nhập mã sáu
          số để xác nhận. Khoá này chỉ hiện một lần.
        </p>
        <p class="secret">{{ enrolment.data.secret }}</p>
        <p class="muted small break">{{ enrolment.data.provisioningUri }}</p>

        <label class="label" for="mfa-code">Mã xác thực</label>
        <input id="mfa-code" v-model="totpCode" class="input" inputmode="numeric" maxlength="6" placeholder="000000" />

        <p v-if="mfaError" class="error" role="alert">{{ mfaError }}</p>

        <div class="actions">
          <button type="button" class="btn-secondary" @click="enrolment = null">Huỷ</button>
          <button type="button" class="btn-primary" :disabled="totpCode.trim().length < 6" @click="confirmEnrolment">
            Xác nhận
          </button>
        </div>
      </div>
    </div>

    <p v-if="mfaError && !enrolment" class="error" role="alert">{{ mfaError }}</p>
  </div>
</template>

<style scoped>
.page { padding: 24px; max-width: 1100px; }
.page-title { margin: 0 0 4px; font-size: 22px; }
.page-subtitle { margin: 0 0 20px; color: var(--muted); font-size: 14px; }
.card { background: var(--surface-container-low); border: 1px solid var(--border); border-radius: 8px; padding: 16px; margin-bottom: 16px; }
.table { width: 100%; border-collapse: collapse; font-size: 14px; }
.table th, .table td { text-align: left; padding: 10px 8px; border-bottom: 1px solid var(--border); vertical-align: top; }
.role-chip { display: inline-flex; align-items: center; gap: 4px; background: var(--surface-container-high); border-radius: 4px; padding: 2px 6px; margin: 0 4px 4px 0; font-size: 12px; }
.chip-x { border: none; background: none; color: var(--error); cursor: pointer; font-size: 14px; line-height: 1; padding: 0 2px; }
.grant-row { display: flex; gap: 6px; }
.input { padding: 8px 10px; border: 1px solid var(--outline-variant); border-radius: 6px; font-size: 14px; font-family: inherit; background: var(--surface-container-lowest); color: var(--on-surface); color-scheme: dark; }
.input option { background: var(--surface-container); color: var(--on-surface); }
.label { font-size: 12px; font-weight: 600; color: var(--muted); display: block; margin-top: 8px; }
.mfa-actions { margin-top: 4px; }
.actions { display: flex; gap: 8px; margin-top: 16px; justify-content: flex-end; }
.btn-primary { background: var(--primary); color: #fff; border: none; border-radius: 6px; padding: 8px 16px; font-weight: 600; cursor: pointer; }
.btn-primary.small { padding: 6px 12px; }
.btn-primary:disabled { opacity: 0.6; cursor: default; }
.btn-secondary { background: transparent; border: 1px solid var(--outline-variant); border-radius: 6px; padding: 8px 16px; cursor: pointer; }
.btn-danger { background: var(--error-container); color: #fff; border: none; border-radius: 6px; padding: 8px 16px; font-weight: 600; cursor: pointer; }
.btn-link { background: none; border: none; color: var(--primary-bright); cursor: pointer; padding: 0; font-size: 13px; }
.btn-link.danger { color: var(--error); }
.muted { color: var(--muted); font-size: 14px; }
.small { font-size: 12px; margin: 2px 0 0; }
.break { word-break: break-all; }
.error { color: var(--error); font-size: 13px; }
.notice { color: var(--tertiary); font-size: 13px; }
.badge-ok { background: var(--tertiary-container); color: var(--on-tertiary); border-radius: 4px; padding: 2px 8px; font-size: 12px; }
.badge-idle { background: var(--surface-container-high); color: var(--on-surface); border-radius: 4px; padding: 2px 8px; font-size: 12px; }
.modal-backdrop { position: fixed; inset: 0; background: rgba(3, 7, 18, 0.72); display: flex; align-items: center; justify-content: center; z-index: 50; }
.modal { background: var(--surface-container-low); border-radius: 10px; padding: 20px; width: min(480px, 92vw); }
.modal-title { margin: 0 0 8px; font-size: 17px; }
.modal-body { margin: 0 0 8px; color: var(--muted); font-size: 14px; }
.secret { font-family: ui-monospace, monospace; font-size: 18px; letter-spacing: 2px; background: var(--surface-container-high); border: 1px dashed #cbd5e1; border-radius: 6px; padding: 10px; text-align: center; }
</style>
