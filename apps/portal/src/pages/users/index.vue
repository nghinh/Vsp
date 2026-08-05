<script setup lang="ts">
import { ref } from "vue";

type Tab = "users" | "roles" | "privacy";
const tab = ref<Tab>("users");

interface UserRow {
  name: string;
  email: string;
  facility: string;
  role: string;
  roleTone: string;
  mfa: "verified" | "shield-on" | "shield-off";
  active: boolean;
}
const users = ref<UserRow[]>([
  { name: "Hoàng Nam", email: "nam.hoang@golfops.pro", facility: "Global Access", role: "Super Admin", roleTone: "r-primary", mfa: "verified", active: true },
  { name: "Linh Trịnh", email: "linh.trinh@legendhill.com", facility: "BRG Legend Hill", role: "Greenkeeper", roleTone: "r-tertiary", mfa: "shield-on", active: true },
  { name: "Minh Quân", email: "m.quan@pga.vn", facility: "Phoenix Resort", role: "Auditor", roleTone: "r-muted", mfa: "shield-off", active: false },
]);

const stats = [
  { lbl: "Active Sessions", val: "142", tone: "c-primary", extra: "+8.4%", extraTone: "c-tertiary" },
  { lbl: "MFA Adoption", val: "89%", tone: "", bar: 89 },
  { lbl: "Avg Session Time", val: "4h 12m", tone: "" },
  { lbl: "Recent Revokes", val: "3", tone: "c-error", extra: "past 24h", extraTone: "c-muted" },
];

const roleCols = ["Super Admin", "Course Admin", "Greenkeeper", "Director", "Caddie Master", "Auditor"];
const matrix = [
  { scope: "Map Geometry Editing", perms: [true, true, false, false, false, false] },
  { scope: "Pin Position Updates", perms: [true, true, true, true, true, false] },
  { scope: "Manage Users & Billing", perms: [true, false, false, false, false, false] },
  { scope: "Audit History Export", perms: [true, true, false, false, false, true] },
  { scope: "Publish Course Version", perms: [true, true, false, false, false, false] },
  { scope: "Issue Course Alerts", perms: [true, true, true, false, true, false] },
];

const privacy = [
  { type: "Delete Account", icon: "delete_sweep", requester: "u-9928-331", due: "2h remaining", dueTone: "c-error", status: "Processing", statusTone: "st-proc", assignee: "Hoàng Nam", log: "LOG_4412" },
  { type: "Data Export", icon: "download", requester: "u-8811-204", due: "3 days", dueTone: "c-muted", status: "Queued", statusTone: "st-queue", assignee: "Linh Trịnh", log: "LOG_4409" },
];

const initials = (n: string) => n.split(" ").map((p) => p[0]).slice(-2).join("");
</script>

<template>
  <div class="users">
    <div class="tab-nav">
      <button class="tab" :class="{ active: tab === 'users' }" @click="tab = 'users'">Người dùng</button>
      <button class="tab" :class="{ active: tab === 'roles' }" @click="tab = 'roles'">Vai trò &amp; Quyền</button>
      <button class="tab" :class="{ active: tab === 'privacy' }" @click="tab = 'privacy'">Yêu cầu quyền riêng tư</button>
    </div>

    <!-- USERS -->
    <section v-if="tab === 'users'" class="stack">
      <div class="filter-bar">
        <div class="filters">
          <select><option>Vai trò: Tất cả</option><option>Super Admin</option><option>Course Admin</option><option>Greenkeeper</option></select>
          <select><option>Cơ sở: Tất cả</option><option>BRG Legend Hill</option><option>Phoenix Golf Resort</option></select>
          <select><option>Trạng thái: Active</option><option>Inactive</option></select>
        </div>
        <button class="btn-primary"><span class="material-symbols-outlined">person_add</span> Thêm người dùng</button>
      </div>

      <div class="table-card">
        <table>
          <thead>
            <tr><th>Name</th><th>Email</th><th>Scoped Facility</th><th>Role</th><th>MFA</th><th>Status</th><th class="ta-r">Actions</th></tr>
          </thead>
          <tbody>
            <tr v-for="u in users" :key="u.email">
              <td><div class="name-cell"><span class="avatar">{{ initials(u.name) }}</span><span class="uname" :class="{ struck: !u.active }">{{ u.name }}</span></div></td>
              <td class="mono c-muted">{{ u.email }}</td>
              <td><span class="chip">{{ u.facility }}</span></td>
              <td><span class="role-badge" :class="u.roleTone">{{ u.role }}</span></td>
              <td>
                <span v-if="u.mfa === 'verified'" class="material-symbols-outlined fill c-tertiary" title="MFA verified">verified_user</span>
                <span v-else-if="u.mfa === 'shield-on'" class="material-symbols-outlined c-error" title="MFA required">shield</span>
                <span v-else class="material-symbols-outlined c-muted" title="MFA off">shield</span>
              </td>
              <td><div class="status"><span class="dot" :class="u.active ? 'd-on' : 'd-off'"></span>{{ u.active ? "Active" : "Inactive" }}</div></td>
              <td class="ta-r">
                <button class="ico-btn" title="Sửa"><span class="material-symbols-outlined">{{ u.active ? "edit" : "settings_backup_restore" }}</span></button>
                <button class="ico-btn danger" :title="u.active ? 'Thu hồi phiên' : 'Xóa'"><span class="material-symbols-outlined">{{ u.active ? "logout" : "delete_forever" }}</span></button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="stat-grid">
        <div v-for="s in stats" :key="s.lbl" class="stat">
          <span class="stat-lbl">{{ s.lbl }}</span>
          <div class="stat-body">
            <span class="stat-val mono" :class="s.tone">{{ s.val }}</span>
            <span v-if="s.extra" class="stat-extra" :class="s.extraTone">{{ s.extra }}</span>
            <div v-if="s.bar" class="mini-bar"><div class="mini-fill" :style="{ width: s.bar + '%' }"></div></div>
          </div>
        </div>
      </div>
    </section>

    <!-- ROLES -->
    <section v-else-if="tab === 'roles'" class="stack">
      <div class="warn-card">
        <span class="material-symbols-outlined">warning</span>
        <div>
          <h4>Least-Privilege Warning</h4>
          <p>Super Admin roles have unrestricted access to all course GPS data, financial logs, and PII. Ensure only verified operational managers hold this role. Audit logs for Super Admin actions are permanent and immutable.</p>
        </div>
      </div>
      <div class="matrix-card">
        <div class="matrix-row head">
          <div class="cell scope">Scope / Permission</div>
          <div v-for="c in roleCols" :key="c" class="cell col-head">{{ c }}</div>
        </div>
        <div v-for="m in matrix" :key="m.scope" class="matrix-row">
          <div class="cell scope perm">{{ m.scope }}</div>
          <div v-for="(p, i) in m.perms" :key="i" class="cell center">
            <span class="material-symbols-outlined" :class="p ? 'c-tertiary' : 'c-outline'">{{ p ? "check_circle" : "cancel" }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- PRIVACY -->
    <section v-else class="stack">
      <div class="table-card">
        <table>
          <thead>
            <tr><th>Type</th><th>Requester</th><th>Due Date</th><th>Status</th><th>Assignee</th><th class="ta-r">Audit Trail</th></tr>
          </thead>
          <tbody>
            <tr v-for="p in privacy" :key="p.log">
              <td><div class="type-cell"><span class="material-symbols-outlined c-secondary">{{ p.icon }}</span>{{ p.type }}</div></td>
              <td class="mono">{{ p.requester }}</td>
              <td class="mono strong" :class="p.dueTone">{{ p.due }}</td>
              <td><span class="st-badge" :class="p.statusTone">{{ p.status }}</span></td>
              <td class="c-muted">{{ p.assignee }}</td>
              <td class="ta-r"><a class="mono link" href="#">{{ p.log }}</a></td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>

<style scoped>
.users { max-width: 1400px; }
.mono { font-family: var(--font-mono); }
.strong { font-weight: 700; }
.struck { text-decoration: line-through; color: var(--on-surface-variant); }
.c-primary { color: var(--primary-bright); }
.c-secondary { color: var(--secondary); }
.c-tertiary { color: var(--tertiary); }
.c-error { color: var(--error); }
.c-muted { color: var(--on-surface-variant); }
.c-outline { color: var(--outline); }
.fill { font-variation-settings: "FILL" 1; }
.stack { display: flex; flex-direction: column; gap: 24px; }

.tab-nav { display: flex; gap: 32px; margin-bottom: 32px; border-bottom: 1px solid rgba(255,255,255,.05); }
.tab { padding-bottom: 16px; background: none; border: none; border-bottom: 2px solid transparent; color: var(--on-surface-variant); font-weight: 500; font-size: 14px; cursor: pointer; }
.tab.active { color: var(--primary-bright); border-bottom-color: var(--primary-bright); font-weight: 700; }

.filter-bar { display: flex; justify-content: space-between; align-items: center; background: var(--surface-container-low); padding: 16px; border-radius: 12px; border: 1px solid rgba(255,255,255,.05); gap: 16px; flex-wrap: wrap; }
.filters { display: flex; gap: 16px; flex-wrap: wrap; }
select { background: var(--surface-container-high); border: 1px solid rgba(255,255,255,.1); border-radius: 8px; padding: 8px 16px; font-size: 14px; color: var(--on-surface); }
.btn-primary { display: inline-flex; align-items: center; gap: 8px; background: var(--primary-container); color: #fff; border: none; padding: 10px 20px; border-radius: 12px; font-weight: 700; cursor: pointer; }
.btn-primary:hover { filter: brightness(1.1); }

.table-card { background: var(--surface-container-low); border: 1px solid rgba(255,255,255,.05); border-radius: 12px; overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
thead tr { background: rgba(45,52,73,.5); border-bottom: 1px solid rgba(255,255,255,.1); }
th { padding: 16px 24px; text-align: left; font-size: 12px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; color: var(--on-surface-variant); }
td { padding: 16px 24px; border-top: 1px solid rgba(255,255,255,.05); color: var(--on-surface); }
tbody tr:hover { background: rgba(255,255,255,.05); }
.ta-r { text-align: right; }
.name-cell { display: flex; align-items: center; gap: 12px; }
.avatar { width: 32px; height: 32px; border-radius: 50%; background: var(--surface-container-highest); display: grid; place-items: center; font-size: 12px; font-weight: 700; color: var(--on-surface); border: 1px solid rgba(255,255,255,.1); }
.uname { font-weight: 600; }
.chip { font-size: 12px; padding: 4px 8px; background: var(--surface-container-highest); border-radius: 4px; border: 1px solid rgba(255,255,255,.1); }
.role-badge { font-size: 10px; padding: 2px 8px; font-weight: 700; text-transform: uppercase; border-radius: 4px; border: 1px solid; }
.r-primary { background: rgba(246,96,24,.2); color: var(--primary-bright); border-color: rgba(255,181,153,.3); }
.r-tertiary { background: rgba(37,164,117,.2); color: var(--tertiary); border-color: rgba(104,219,169,.3); }
.r-muted { background: var(--surface-container-highest); color: var(--on-surface-variant); border-color: rgba(255,255,255,.1); }
.status { display: flex; align-items: center; gap: 8px; font-size: 12px; }
.dot { width: 8px; height: 8px; border-radius: 50%; }
.d-on { background: var(--tertiary); }
.d-off { background: var(--outline-variant); }
.ico-btn { background: none; border: none; color: var(--on-surface-variant); padding: 8px; cursor: pointer; border-radius: 8px; }
.ico-btn:hover { color: var(--primary-bright); background: rgba(246,96,24,.1); }
.ico-btn.danger:hover { color: var(--error); background: rgba(147,0,10,.1); }

.stat-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 24px; }
.stat { background: var(--surface-container); padding: 24px; border-radius: 16px; border: 1px solid rgba(255,255,255,.05); }
.stat-lbl { font-size: 12px; text-transform: uppercase; font-weight: 700; letter-spacing: .08em; color: var(--on-surface-variant); }
.stat-body { margin-top: 8px; display: flex; align-items: baseline; gap: 8px; }
.stat-val { font-size: 40px; font-weight: 700; }
.stat-extra { font-weight: 700; font-size: 13px; }
.mini-bar { height: 8px; width: 96px; background: var(--surface-container-high); border-radius: 999px; overflow: hidden; align-self: center; }
.mini-fill { height: 100%; background: var(--tertiary); }

.warn-card { background: var(--surface-container); border-left: 4px solid var(--primary-bright); padding: 24px; border-radius: 12px; display: flex; gap: 16px; }
.warn-card .material-symbols-outlined { color: var(--primary-bright); font-size: 30px; }
.warn-card h4 { margin: 0 0 4px; color: var(--primary-bright); font-size: 20px; }
.warn-card p { margin: 0; color: var(--on-surface-variant); font-size: 14px; }

.matrix-card { background: var(--surface-container-low); border: 1px solid rgba(255,255,255,.05); border-radius: 16px; overflow: hidden; }
.matrix-row { display: grid; grid-template-columns: 2fr repeat(6, 1fr); }
.matrix-row.head { background: rgba(45,52,73,.3); border-bottom: 1px solid rgba(255,255,255,.1); }
.matrix-row:not(.head):hover { background: rgba(255,255,255,.05); }
.matrix-row:not(.head) + .matrix-row:not(.head) { border-top: 1px solid rgba(255,255,255,.05); }
.cell { padding: 20px 16px; }
.cell.scope { font-weight: 700; font-size: 14px; }
.cell.perm { font-weight: 500; }
.cell.col-head { text-align: center; font-size: 10px; text-transform: uppercase; font-weight: 700; color: var(--on-surface-variant); }
.cell.center { display: flex; align-items: center; justify-content: center; }

.type-cell { display: inline-flex; align-items: center; gap: 8px; font-weight: 500; }
.st-badge { padding: 4px 8px; border-radius: 4px; font-size: 10px; font-weight: 700; text-transform: uppercase; border: 1px solid; }
.st-proc { background: rgba(236,106,6,.2); color: var(--secondary); border-color: rgba(255,182,144,.3); }
.st-queue { background: var(--surface-container-highest); color: var(--on-surface-variant); border-color: rgba(255,255,255,.1); }
.link { color: var(--primary-bright); }
.link:hover { text-decoration: underline; }

@media (max-width: 1100px) { .stat-grid { grid-template-columns: repeat(2, 1fr); } .matrix-row { grid-template-columns: 1.5fr repeat(6, 1fr); } }
@media (max-width: 640px) { .stat-grid { grid-template-columns: 1fr; } .matrix-card { overflow-x: auto; } .matrix-row { min-width: 720px; } }
</style>
