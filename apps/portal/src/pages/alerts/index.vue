<script setup lang="ts">
import { ref, computed } from "vue";

type Severity = "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";
type AlertType = "Safety" | "Operations" | "Promotion";
interface AlertRow {
  id: number;
  status: "Active" | "Scheduled" | "Expired" | "Draft";
  severity: Severity;
  type: AlertType;
  title: string;
  target: string;
  endsAt: string;
  delivered: number;
  audience: number;
}

const alerts = ref<AlertRow[]>([
  { id: 1, status: "Active", severity: "CRITICAL", type: "Safety", title: "Dự báo Sấm sét - Di tản ngay", target: "All Holes, All Flights", endsAt: "15:30 (Hôm nay)", delivered: 182, audience: 185 },
  { id: 2, status: "Active", severity: "MEDIUM", type: "Operations", title: "Bảo trì Green hố số 7", target: "Hole 7, Flights Near", endsAt: "18:00 (Hôm nay)", delivered: 42, audience: 45 },
]);

const tabs = [
  { key: "Active", label: "Active" },
  { key: "Scheduled", label: "Scheduled" },
  { key: "Expired", label: "Expired" },
  { key: "Draft", label: "Draft" },
] as const;
const activeTab = ref<(typeof tabs)[number]["key"]>("Active");
const search = ref("");

const filtered = computed(() =>
  alerts.value.filter(
    (a) =>
      a.status === activeTab.value &&
      (!search.value || a.title.toLowerCase().includes(search.value.toLowerCase())),
  ),
);
const countFor = (key: string) => alerts.value.filter((a) => a.status === key).length;

const typeIcon: Record<AlertType, string> = { Safety: "warning", Operations: "construction", Promotion: "celebration" };
const typeTone: Record<AlertType, string> = { Safety: "c-error", Operations: "c-secondary", Promotion: "c-tertiary" };
const sevClass: Record<Severity, string> = { LOW: "sev-low", MEDIUM: "sev-med", HIGH: "sev-high", CRITICAL: "sev-crit" };

// ─── Create slide-over ─────────────────────────────────────────────────────
const showCreate = ref(false);
const showConfirm = ref(false);
const draft = ref<{ type: AlertType; severity: Severity; title: string; body: string; target: string }>({
  type: "Safety",
  severity: "CRITICAL",
  title: "",
  body: "",
  target: "Tất cả golfer (Toàn bộ sân)",
});
const severities: Severity[] = ["LOW", "MEDIUM", "HIGH", "CRITICAL"];
const typeOptions: { key: AlertType; icon: string; title: string; desc: string; tone: string }[] = [
  { key: "Safety", icon: "warning", title: "An toàn (Safety)", desc: "Khẩn cấp, thời tiết, di tản", tone: "opt-error" },
  { key: "Operations", icon: "construction", title: "Vận hành", desc: "Bảo trì, hố đóng, chậm flight", tone: "opt-primary" },
  { key: "Promotion", icon: "celebration", title: "Khuyến mãi", desc: "Dịch vụ, giải đấu, ưu đãi", tone: "opt-tertiary" },
];

function openCreate() {
  showCreate.value = true;
}
function submit() {
  if (draft.value.severity === "CRITICAL") {
    showConfirm.value = true;
    return;
  }
  finalize("Active");
}
function finalize(status: AlertRow["status"]) {
  alerts.value.unshift({
    id: Date.now(),
    status,
    severity: draft.value.severity,
    type: draft.value.type,
    title: draft.value.title || "(Không tiêu đề)",
    target: draft.value.target,
    endsAt: "—",
    delivered: 0,
    audience: 185,
  });
  showConfirm.value = false;
  showCreate.value = false;
  activeTab.value = status;
  draft.value = { type: "Safety", severity: "CRITICAL", title: "", body: "", target: "Tất cả golfer (Toàn bộ sân)" };
}
</script>

<template>
  <div class="alerts">
    <div class="page-head">
      <div class="crumbs mono">Portal <span class="material-symbols-outlined">chevron_right</span> BRG Legend Hill <span class="material-symbols-outlined">chevron_right</span> <span class="c-primary">Alerts</span></div>
      <div class="head-actions">
        <div class="search-box">
          <span class="material-symbols-outlined">search</span>
          <input v-model="search" type="text" placeholder="Tìm kiếm cảnh báo..." />
        </div>
        <button class="btn-primary" @click="openCreate"><span class="material-symbols-outlined">add_alert</span> Tạo cảnh báo</button>
      </div>
    </div>

    <!-- Stats -->
    <div class="stats">
      <div class="stat"><p class="stat-lbl">Đang hoạt động</p><p class="stat-val mono c-primary">{{ countFor("Active").toString().padStart(2, "0") }}</p></div>
      <div class="stat"><p class="stat-lbl">Cảnh báo an toàn</p><p class="stat-val mono c-error">01</p></div>
      <div class="stat"><p class="stat-lbl">Tổng lượt gửi (24h)</p><p class="stat-val mono">1,248</p></div>
      <div class="stat"><p class="stat-lbl">Tỉ lệ phản hồi</p><p class="stat-val mono c-tertiary">92%</p></div>
    </div>

    <!-- Table card -->
    <div class="table-card">
      <div class="tabs">
        <button v-for="t in tabs" :key="t.key" class="tab" :class="{ active: activeTab === t.key }" @click="activeTab = t.key">
          {{ t.label }} ({{ countFor(t.key) }})
        </button>
      </div>
      <div class="table-wrap">
        <table>
          <thead>
            <tr><th>Status</th><th>Severity</th><th>Alert Type</th><th>Title</th><th>Target</th><th>Schedule (End)</th><th>Delivery</th><th class="ta-r">Actions</th></tr>
          </thead>
          <tbody>
            <tr v-for="a in filtered" :key="a.id">
              <td><span class="status c-tertiary"><span class="dot" :class="{ pulse: a.severity === 'CRITICAL' }"></span>{{ a.status }}</span></td>
              <td><span class="sev" :class="sevClass[a.severity]">{{ a.severity }}</span></td>
              <td><div class="type-cell"><span class="material-symbols-outlined" :class="typeTone[a.type]">{{ typeIcon[a.type] }}</span>{{ a.type }}</div></td>
              <td class="strong">{{ a.title }}</td>
              <td class="c-muted">{{ a.target }}</td>
              <td class="mono">{{ a.endsAt }}</td>
              <td>
                <span class="mono">{{ a.delivered }}/{{ a.audience }}</span>
                <div class="prog"><div class="prog-fill" :style="{ width: (a.delivered / a.audience) * 100 + '%' }"></div></div>
              </td>
              <td class="ta-r">
                <button class="ico-btn" title="Sửa"><span class="material-symbols-outlined">edit</span></button>
                <button class="ico-btn danger" title="Dừng"><span class="material-symbols-outlined">stop_circle</span></button>
              </td>
            </tr>
            <tr v-if="filtered.length === 0"><td colspan="8" class="empty">Không có cảnh báo trong mục này.</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Create slide-over -->
    <div v-if="showCreate" class="scrim" @click.self="showCreate = false">
      <div class="sheet">
        <header class="sheet-head">
          <div class="sheet-title"><span class="sheet-ico"><span class="material-symbols-outlined">add_alert</span></span><div><h3>Tạo cảnh báo mới</h3><p>Thiết lập thông báo tức thì cho golfer trên sân</p></div></div>
          <button class="ico-btn" @click="showCreate = false"><span class="material-symbols-outlined">close</span></button>
        </header>
        <div class="sheet-body">
          <section>
            <h4>1. Phân loại &amp; Mức độ</h4>
            <div class="type-grid">
              <label v-for="o in typeOptions" :key="o.key" class="type-opt" :class="[o.tone, { checked: draft.type === o.key }]">
                <input type="radio" name="atype" :value="o.key" v-model="draft.type" />
                <span class="material-symbols-outlined">{{ o.icon }}</span>
                <p class="ot">{{ o.title }}</p><p class="od">{{ o.desc }}</p>
              </label>
            </div>
            <div class="sev-grid">
              <button v-for="s in severities" :key="s" class="sev-btn" :class="{ active: draft.severity === s, crit: s === 'CRITICAL' && draft.severity === s }" @click="draft.severity = s">{{ s.charAt(0) + s.slice(1).toLowerCase() }}</button>
            </div>
          </section>
          <section>
            <h4>2. Nội dung cảnh báo</h4>
            <label class="fl">Tiêu đề cảnh báo</label>
            <input v-model="draft.title" class="fin" type="text" placeholder="Nhập tiêu đề ngắn gọn..." />
            <label class="fl">Nội dung chi tiết (Max 160 ký tự)</label>
            <textarea v-model="draft.body" class="fin" rows="3" maxlength="160" placeholder="Mô tả chi tiết hướng dẫn cho golfer..."></textarea>
            <div class="char"><span v-if="draft.severity === 'CRITICAL' && !draft.body" class="c-error">Yêu cầu nội dung cho trường hợp khẩn cấp</span><span class="c-muted">{{ draft.body.length }} / 160</span></div>
          </section>
          <section>
            <h4>3. Đối tượng mục tiêu</h4>
            <select v-model="draft.target" class="fin"><option>Tất cả golfer (Toàn bộ sân)</option><option>Theo từng hố (Hole-specific)</option><option>Nhóm Golfer (Tournament A)</option></select>
          </section>
        </div>
        <footer class="sheet-foot">
          <button class="btn-ghost" @click="showCreate = false">Hủy bỏ</button>
          <button class="btn-outline" @click="finalize('Draft')">Lưu bản nháp</button>
          <button class="btn-primary" @click="submit">Gửi cảnh báo</button>
        </footer>
      </div>
    </div>

    <!-- Safety confirm -->
    <div v-if="showConfirm" class="scrim center">
      <div class="confirm">
        <div class="confirm-ico"><span class="material-symbols-outlined">priority_high</span></div>
        <h3>Xác nhận cảnh báo KHẨN CẤP?</h3>
        <p>Thông báo này sẽ được gửi ngay lập tức tới <strong>185 golfer</strong> và yêu cầu họ phản hồi. Hành động này không thể hoàn tác.</p>
        <div class="confirm-actions">
          <button class="btn-ghost bordered" @click="showConfirm = false">Quay lại</button>
          <button class="btn-danger" @click="finalize('Active')">XÁC NHẬN GỬI</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.alerts { max-width: 1400px; }
.mono { font-family: var(--font-mono); }
.strong { font-weight: 700; }
.c-primary { color: var(--primary-bright); }
.c-error { color: var(--error); }
.c-secondary { color: var(--secondary); }
.c-tertiary { color: var(--tertiary); }
.c-muted { color: var(--on-surface-variant); }

.page-head { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 32px; gap: 16px; flex-wrap: wrap; }
.crumbs { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--on-surface-variant); }
.crumbs .material-symbols-outlined { font-size: 14px; }
.head-actions { display: flex; align-items: center; gap: 16px; }
.search-box { position: relative; display: flex; align-items: center; }
.search-box .material-symbols-outlined { position: absolute; left: 12px; color: var(--on-surface-variant); }
.search-box input { background: var(--surface-container-high); border: none; border-radius: 8px; padding: 8px 16px 8px 40px; width: 240px; color: var(--on-surface); }
.search-box input:focus { outline: 2px solid var(--primary-bright); }
.btn-primary { display: inline-flex; align-items: center; gap: 8px; background: var(--primary-container); color: #fff; border: none; padding: 10px 20px; border-radius: 8px; font-weight: 700; cursor: pointer; }
.btn-primary:hover { filter: brightness(1.1); }

.stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 32px; }
.stat { background: var(--surface-container-low); padding: 20px; border-radius: 12px; border: 1px solid var(--border); }
.stat-lbl { margin: 0 0 4px; font-size: 12px; font-weight: 700; letter-spacing: .05em; color: var(--on-surface-variant); }
.stat-val { margin: 0; font-size: 40px; font-weight: 700; line-height: 1.1; }

.table-card { background: var(--surface-container-low); border-radius: 12px; border: 1px solid var(--border); overflow: hidden; }
.tabs { display: flex; border-bottom: 1px solid var(--border); padding: 0 16px; }
.tab { padding: 16px 24px; background: none; border: none; border-bottom: 2px solid transparent; color: var(--on-surface-variant); font-weight: 600; cursor: pointer; }
.tab.active { color: var(--primary-bright); border-bottom-color: var(--primary-bright); }
.table-wrap { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
thead { background: rgba(23,31,51,.5); }
th { padding: 16px 24px; text-align: left; font-size: 12px; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: var(--on-surface-variant); }
td { padding: 16px 24px; border-top: 1px solid rgba(255,255,255,.05); color: var(--on-surface); }
tbody tr:hover { background: rgba(45,52,73,.3); }
.ta-r { text-align: right; }
.status { display: inline-flex; align-items: center; gap: 8px; }
.dot { width: 8px; height: 8px; border-radius: 50%; background: var(--tertiary); }
.pulse { animation: pulse 1.6s infinite; }
@keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .3; } }
.sev { padding: 4px 12px; border-radius: 999px; font-size: 12px; font-weight: 700; }
.sev-crit { background: var(--error-container); color: var(--on-error-container); }
.sev-high { background: rgba(255,180,171,.15); color: var(--error); }
.sev-med { background: var(--secondary-container); color: var(--on-secondary-container); }
.sev-low { background: var(--surface-container-highest); color: var(--on-surface-variant); }
.type-cell { display: inline-flex; align-items: center; gap: 8px; }
.prog { width: 96px; height: 4px; background: var(--surface-container-highest); border-radius: 999px; margin-top: 4px; }
.prog-fill { height: 100%; background: var(--tertiary); border-radius: 999px; }
.ico-btn { background: none; border: none; color: var(--on-surface-variant); padding: 8px; cursor: pointer; border-radius: 8px; }
.ico-btn:hover { color: var(--primary-bright); }
.ico-btn.danger:hover { color: var(--error); }
.empty { text-align: center; color: var(--on-surface-variant); padding: 48px; }

/* Slide-over */
.scrim { position: fixed; inset: 0; z-index: 100; background: rgba(0,0,0,.6); backdrop-filter: blur(4px); display: flex; justify-content: flex-end; }
.scrim.center { align-items: center; justify-content: center; }
.sheet { width: min(680px, 100%); height: 100%; background: var(--surface-container); display: flex; flex-direction: column; animation: slide .3s ease-out; }
@keyframes slide { from { transform: translateX(100%); } to { transform: translateX(0); } }
.sheet-head { padding: 24px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.sheet-title { display: flex; align-items: center; gap: 12px; }
.sheet-ico { width: 40px; height: 40px; border-radius: 8px; background: var(--primary-container); display: grid; place-items: center; color: #fff; }
.sheet-title h3 { margin: 0; font-size: 24px; }
.sheet-title p { margin: 0; font-size: 14px; color: var(--on-surface-variant); }
.sheet-body { flex: 1; overflow-y: auto; padding: 32px; display: flex; flex-direction: column; gap: 32px; }
.sheet-body h4 { margin: 0 0 16px; font-size: 12px; font-weight: 700; letter-spacing: .05em; color: var(--primary-bright); text-transform: uppercase; }
.type-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 16px; }
.type-opt { position: relative; padding: 16px; border-radius: 12px; border: 1px solid var(--outline-variant); cursor: pointer; display: block; }
.type-opt input { position: absolute; opacity: 0; }
.type-opt .material-symbols-outlined { display: block; margin-bottom: 8px; }
.type-opt.opt-error .material-symbols-outlined { color: var(--error); }
.type-opt.opt-primary .material-symbols-outlined { color: var(--primary-bright); }
.type-opt.opt-tertiary .material-symbols-outlined { color: var(--tertiary); }
.type-opt .ot { margin: 0; font-weight: 700; }
.type-opt .od { margin: 0; font-size: 12px; opacity: .7; }
.type-opt.checked.opt-error { border-color: var(--error); background: rgba(147,0,10,.2); }
.type-opt.checked.opt-primary { border-color: var(--primary-bright); background: rgba(246,96,24,.15); }
.type-opt.checked.opt-tertiary { border-color: var(--tertiary); background: rgba(37,164,117,.2); }
.sev-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
.sev-btn { background: var(--surface-container-high); border: 1px solid var(--outline-variant); border-radius: 12px; padding: 8px 12px; color: var(--on-surface); cursor: pointer; }
.sev-btn:hover { border-color: var(--on-surface); }
.sev-btn.active { border-color: var(--primary-bright); }
.sev-btn.crit { background: var(--error-container); color: var(--on-error-container); font-weight: 700; border-color: var(--error-container); }
.fl { display: block; font-size: 14px; color: var(--on-surface-variant); margin: 16px 0 8px; }
.fin { width: 100%; background: var(--surface-container-high); border: 1px solid var(--outline-variant); border-radius: 12px; padding: 12px 16px; color: var(--on-surface); }
.fin:focus { outline: none; border-color: var(--primary-bright); }
.char { display: flex; justify-content: space-between; font-size: 12px; margin-top: 4px; }
.sheet-foot { padding: 24px; border-top: 1px solid var(--border); display: flex; justify-content: flex-end; gap: 16px; }
.btn-ghost { background: none; border: none; padding: 8px 24px; border-radius: 12px; color: var(--on-surface-variant); cursor: pointer; }
.btn-ghost:hover { background: var(--surface-bright); }
.btn-ghost.bordered { border: 1px solid var(--outline-variant); }
.btn-outline { background: none; border: 1px solid var(--primary-bright); color: var(--primary-bright); padding: 8px 24px; border-radius: 12px; cursor: pointer; }
.btn-danger { background: var(--error); color: #690005; border: none; padding: 12px 24px; border-radius: 12px; font-weight: 700; cursor: pointer; }

.confirm { max-width: 420px; background: var(--surface-container-highest); border-radius: 16px; padding: 32px; border: 1px solid rgba(255,180,171,.3); text-align: center; }
.confirm-ico { width: 80px; height: 80px; margin: 0 auto 24px; border-radius: 50%; background: rgba(147,0,10,.3); color: var(--error); display: grid; place-items: center; }
.confirm-ico .material-symbols-outlined { font-size: 48px; }
.confirm h3 { margin: 0 0 8px; font-size: 24px; }
.confirm p { color: var(--on-surface-variant); margin: 0 0 32px; }
.confirm-actions { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }

@media (max-width: 1100px) { .stats { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 640px) { .stats { grid-template-columns: 1fr; } .type-grid { grid-template-columns: 1fr; } }
</style>
