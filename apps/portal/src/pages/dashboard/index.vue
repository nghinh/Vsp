<script setup lang="ts">
import { computed } from "vue";
import { useRouter } from "vue-router";

const router = useRouter();

const now = new Date();
const greeting = computed(() => {
  const h = now.getHours();
  if (h < 11) return "Chào buổi sáng";
  if (h < 14) return "Chào buổi trưa";
  if (h < 18) return "Chào buổi chiều";
  return "Chào buổi tối";
});
const updatedAt = now.toLocaleString("vi-VN", {
  hour: "2-digit",
  minute: "2-digit",
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
});

const kpis = [
  { key: "verify", tone: "primary", tag: "Cần xử lý", value: "03", label: "Sân cần xác minh", cta: "CHI TIẾT", to: "/admin/data-quality", icon: "verified_user" },
  { key: "corr", tone: "secondary", tag: "Chờ duyệt", value: "12", label: "Hiệu chỉnh chờ xử lý", cta: "XỬ LÝ NGAY", to: "/corrections", icon: "edit_square" },
  { key: "alert", tone: "error", tag: "Khẩn cấp", value: "02", label: "Cảnh báo đang hoạt động", cta: "XEM CẢNH BÁO", to: "/alerts", icon: "campaign" },
  { key: "pins", tone: "tertiary", tag: "Lên lịch", value: "18", label: "Vị trí cờ sắp tới", cta: "XEM LỊCH", to: "/pin-positions", icon: "calendar_today" },
] as const;

interface HealthRow {
  icon: string;
  name: string;
  scope: string;
  tone: string;
  status: string;
  due: string;
  action: string;
  pulse?: boolean;
  disabled?: boolean;
  to?: string;
}
const health: HealthRow[] = [
  { icon: "keep", name: "Vị trí cờ (Stale Pins)", scope: "Legend Hill · Course A", tone: "error", pulse: true, status: "Quá hạn 2h", due: "12:00, 01/08", action: "CẬP NHẬT", to: "/pin-positions" },
  { icon: "speed", name: "Tốc độ Green (Stimp)", scope: "Tất cả các sân", tone: "tertiary", status: "Đã cập nhật", due: "06:00, 02/08", action: "HỢP LỆ", disabled: true },
  { icon: "water_drop", name: "Điều kiện Bunker/Cỏ", scope: "Kings Island · Mountain", tone: "secondary", status: "Đang chờ (1)", due: "14:00, 01/08", action: "KIỂM TRA", to: "/course-conditions" },
];

const trend = [
  { d: "T2", h: 40 }, { d: "T3", h: 65 }, { d: "T4", h: 50 },
  { d: "T5", h: 85 }, { d: "T6", h: 70 }, { d: "T7", h: 95, today: true }, { d: "CN", h: 20 },
];

const pinSchedule = [
  { hole: "04", zone: "B2 (Trung tâm)", start: "06:00, Ngày mai", active: true },
  { hole: "12", zone: "A3 (Gần trái)", start: "06:30, Ngày mai" },
  { hole: "18", zone: "C1 (Phía sau)", start: "07:00, Ngày mai" },
];

const activity = [
  { tone: "tertiary", who: "Trần Minh Quân", what: "đã công bố bản đồ", meta: "Version ID: #LH-9921 · 14:05" },
  { tone: "secondary", who: "Lê Văn Ba", what: "cập nhật Green Speed", meta: "Legend Hill Course B · 13:42" },
  { tone: "error", who: "Admin", what: "rollback phiên bản", meta: "Bị hủy bỏ bởi System · 12:15", struck: true },
];
</script>

<template>
  <div class="dashboard">
    <div class="dash-head">
      <p class="hello">{{ greeting }}, <span>Nghi</span>. Đây là trạng thái vận hành hiện tại.</p>
      <div class="refresh"><span class="material-symbols-outlined spin">sync</span><span class="mono">Cập nhật lúc: {{ updatedAt }}</span></div>
    </div>

    <!-- KPI grid -->
    <div class="kpi-grid">
      <div v-for="k in kpis" :key="k.key" class="kpi-card" :class="`t-${k.tone}`">
        <div class="kpi-top">
          <span class="kpi-ico"><span class="material-symbols-outlined">{{ k.icon }}</span></span>
          <span class="kpi-tag mono">{{ k.tag }}</span>
        </div>
        <p class="kpi-value mono">{{ k.value }}</p>
        <p class="kpi-label">{{ k.label }}</p>
        <button class="kpi-cta" @click="router.push(k.to)">{{ k.cta }}</button>
      </div>
    </div>

    <div class="grid-12">
      <!-- Left column -->
      <div class="col-main">
        <!-- Data trust -->
        <section class="panel">
          <div class="panel-head">
            <h2><span class="material-symbols-outlined c-primary">analytics</span> Độ tươi &amp; Tin cậy dữ liệu</h2>
            <span class="pill-official mono">CHÍNH THỨC</span>
          </div>
          <div class="trust-grid">
            <div>
              <div class="trust-row"><p>Class A (RTK Surveyed)</p><p class="mono c-tertiary">74%</p></div>
              <div class="bar"><div class="bar-fill f-tertiary" style="width:74%"></div></div>
              <p class="trust-note">Độ chính xác &lt; 2cm</p>
            </div>
            <div>
              <div class="trust-row"><p>Class B (Satellite/Manual)</p><p class="mono c-primary">26%</p></div>
              <div class="bar"><div class="bar-fill f-primary" style="width:26%"></div></div>
              <p class="trust-note">Độ chính xác ~ 50cm</p>
            </div>
          </div>
        </section>

        <!-- Operational health -->
        <section class="panel np">
          <div class="panel-head bordered">
            <h2><span class="material-symbols-outlined c-secondary">health_and_safety</span> Tình trạng dữ liệu vận hành</h2>
          </div>
          <div class="table-wrap">
            <table>
              <thead>
                <tr><th>Danh mục</th><th>Trạng thái</th><th>Hạn cập nhật</th><th class="ta-r">Hành động</th></tr>
              </thead>
              <tbody>
                <tr v-for="row in health" :key="row.name">
                  <td>
                    <div class="cell-name">
                      <span class="material-symbols-outlined c-muted">{{ row.icon }}</span>
                      <div><p>{{ row.name }}</p><p class="sub mono">{{ row.scope }}</p></div>
                    </div>
                  </td>
                  <td><span class="status mono" :class="`c-${row.tone}`"><span class="dot" :class="[`d-${row.tone}`, row.pulse ? 'pulse' : '']"></span>{{ row.status }}</span></td>
                  <td class="mono">{{ row.due }}</td>
                  <td class="ta-r">
                    <button v-if="row.disabled" class="link-btn" disabled>{{ row.action }}</button>
                    <button v-else class="link-btn c-primary" @click="row.to && router.push(row.to)">{{ row.action }}</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- Correction trends -->
        <section class="panel">
          <div class="panel-head">
            <h2><span class="material-symbols-outlined c-secondary-bright">trending_up</span> Xu hướng xử lý hiệu chỉnh</h2>
            <select class="mini-select"><option>7 ngày qua</option><option>30 ngày qua</option></select>
          </div>
          <div class="chart">
            <div v-for="b in trend" :key="b.d" class="chart-bar" :class="{ 'is-today': b.today }" :style="{ height: b.h + '%' }" :title="`${b.d}: ${b.h}%`"></div>
          </div>
          <div class="chart-x mono">
            <span v-for="b in trend" :key="b.d" :class="{ 'c-primary bold': b.today }">{{ b.d }}</span>
          </div>
        </section>
      </div>

      <!-- Right column -->
      <div class="col-side">
        <section class="panel side">
          <div class="panel-head">
            <h2>Lịch cắm cờ</h2>
            <button class="icon-plain c-primary" @click="router.push('/pin-positions')"><span class="material-symbols-outlined">add_circle</span></button>
          </div>
          <div class="pin-list">
            <div v-for="p in pinSchedule" :key="p.hole" class="pin-item" :class="{ active: p.active }">
              <div class="hole-chip"><span class="mono lbl">HOLE</span><span class="mono num">{{ p.hole }}</span></div>
              <div><p>Vị trí: {{ p.zone }}</p><p class="sub mono">Bắt đầu: {{ p.start }}</p></div>
            </div>
          </div>
          <button class="ghost-btn" @click="router.push('/pin-positions')">XEM TẤT CẢ 18 LỊCH</button>
        </section>

        <section class="panel side">
          <h2 class="mb">Trạng thái đóng gói</h2>
          <div class="pkg-row">
            <div class="pkg-name"><span class="material-symbols-outlined c-tertiary">package_2</span><span>Legend Hill (Offline)</span></div>
            <span class="pkg-badge ok mono">V2.4.1 — SUCCESS</span>
          </div>
          <div class="pkg-row">
            <div class="pkg-name"><span class="material-symbols-outlined c-primary">package_2</span><span>Van Tri GC</span></div>
            <span class="pkg-badge building mono"><span class="spinner"></span> BUILDING (82%)</span>
          </div>
        </section>

        <section class="panel side">
          <h2 class="mb">Hoạt động gần đây</h2>
          <div class="timeline">
            <div v-for="(a, i) in activity" :key="i" class="tl-item" :class="{ dim: a.struck }">
              <span class="tl-node" :class="`d-${a.tone}`"></span>
              <p :class="{ struck: a.struck }"><strong>{{ a.who }}</strong> {{ a.what }}</p>
              <p class="sub mono">{{ a.meta }}</p>
            </div>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard { max-width: 1400px; }
.mono { font-family: var(--font-mono); }
.bold { font-weight: 700; }
.c-primary { color: var(--primary-bright); }
.c-secondary { color: var(--secondary); }
.c-secondary-bright { color: var(--secondary); }
.c-tertiary { color: var(--tertiary); }
.c-error { color: var(--error); }
.c-muted { color: var(--on-surface-variant); }

.dash-head { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 32px; gap: 16px; flex-wrap: wrap; }
.hello { color: var(--on-surface-variant); margin: 0; }
.hello span { color: var(--primary-bright); font-weight: 600; }
.refresh { display: flex; align-items: center; gap: 8px; color: var(--on-surface-variant); font-size: 14px; }
.refresh .spin { font-size: 18px; animation: spin 3s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

/* KPI */
.kpi-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 32px; }
.kpi-card { background: var(--surface-container); padding: 24px; border-radius: 12px; border: 1px solid var(--outline-variant); transition: border-color .2s; }
.kpi-card.t-primary:hover { border-color: var(--primary-bright); }
.kpi-card.t-secondary:hover { border-color: var(--secondary); }
.kpi-card.t-error:hover { border-color: var(--error); }
.kpi-card.t-tertiary:hover { border-color: var(--tertiary); }
.kpi-top { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; }
.kpi-ico { display: grid; place-items: center; padding: 8px; border-radius: 8px; }
.t-primary .kpi-ico { background: rgba(246,96,24,.1); color: var(--primary-bright); }
.t-secondary .kpi-ico { background: rgba(236,106,6,.1); color: var(--secondary); }
.t-error .kpi-ico { background: rgba(255,180,171,.1); color: var(--error); }
.t-tertiary .kpi-ico { background: rgba(104,219,169,.1); color: var(--tertiary); }
.kpi-tag { font-size: 14px; }
.t-primary .kpi-tag { color: var(--primary-bright); }
.t-secondary .kpi-tag { color: var(--secondary); }
.t-error .kpi-tag { color: var(--error); }
.t-tertiary .kpi-tag { color: var(--tertiary); }
.kpi-value { font-size: 32px; font-weight: 700; margin: 0 0 4px; }
.t-primary .kpi-value { color: var(--primary-bright); }
.t-secondary .kpi-value { color: var(--secondary); }
.t-error .kpi-value { color: var(--error); }
.t-tertiary .kpi-value { color: var(--tertiary); }
.kpi-label { color: var(--on-surface); font-weight: 500; margin: 0; }
.kpi-cta { margin-top: 16px; width: 100%; padding: 8px; background: var(--surface-bright); color: var(--on-surface); border: none; border-radius: 4px; font-size: 12px; font-weight: 700; letter-spacing: .05em; cursor: pointer; transition: background .2s; }
.kpi-cta:hover { background: var(--surface-container-highest); }
.t-error .kpi-cta { background: var(--error-container); color: var(--on-error-container); }
.t-error .kpi-cta:hover { background: var(--error); color: #690005; }

/* 12-col */
.grid-12 { display: grid; grid-template-columns: 2fr 1fr; gap: 16px; }
.col-main, .col-side { display: flex; flex-direction: column; gap: 16px; min-width: 0; }

.panel { background: var(--surface-container-high); border-radius: 12px; padding: 24px; border: 1px solid var(--border); }
.panel.np { padding: 0; overflow: hidden; }
.panel-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
.panel-head.bordered { padding: 24px; margin-bottom: 0; border-bottom: 1px solid var(--border); }
.panel h2 { font-size: 24px; font-weight: 600; margin: 0; display: flex; align-items: center; gap: 12px; color: var(--on-surface); }
.side h2 { font-size: 20px; }
.mb { margin-bottom: 24px; }
.pill-official { background: var(--tertiary); color: var(--on-tertiary); padding: 4px 12px; border-radius: 999px; font-size: 12px; }

.trust-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 32px; }
.trust-row { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 8px; }
.trust-row p { margin: 0; color: var(--on-surface-variant); }
.bar { width: 100%; height: 12px; background: var(--surface-container); border-radius: 999px; }
.bar-fill { height: 12px; border-radius: 999px; }
.f-tertiary { background: var(--tertiary); }
.f-primary { background: var(--primary-bright); }
.trust-note { margin: 16px 0 0; font-size: 10px; text-transform: uppercase; letter-spacing: .08em; color: var(--on-surface-variant); }

.table-wrap { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
thead { background: var(--surface-container-low); }
th { padding: 12px 24px; text-align: left; font-size: 12px; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: var(--on-surface-variant); }
td { padding: 16px 24px; border-top: 1px solid rgba(255,255,255,.05); }
.ta-r { text-align: right; }
.cell-name { display: flex; align-items: center; gap: 12px; }
.cell-name p { margin: 0; color: var(--on-surface); }
.sub { font-size: 12px; color: var(--on-surface-variant); }
.status { display: inline-flex; align-items: center; gap: 8px; font-size: 14px; }
.dot { width: 8px; height: 8px; border-radius: 50%; }
.d-error, .d-primary { }
.d-error { background: var(--error); }
.d-tertiary { background: var(--tertiary); }
.d-secondary { background: var(--secondary); }
.d-primary { background: var(--primary-bright); }
.pulse { animation: pulse 1.6s infinite; }
@keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .3; } }
.link-btn { background: none; border: none; font-size: 12px; font-weight: 700; letter-spacing: .05em; cursor: pointer; color: var(--on-surface-variant); }
.link-btn.c-primary { color: var(--primary-bright); }
.link-btn.c-primary:hover { text-decoration: underline; }
.link-btn:disabled { opacity: .5; cursor: not-allowed; }

.chart { height: 192px; display: flex; align-items: flex-end; gap: 8px; padding: 0 8px; }
.chart-bar { flex: 1; background: var(--surface-container-highest); border-radius: 4px 4px 0 0; transition: background .2s; cursor: help; }
.chart-bar:hover { background: var(--primary-bright); }
.chart-bar.is-today { background: var(--primary-bright); }
.chart-x { display: flex; justify-content: space-between; margin-top: 16px; padding: 0 8px; font-size: 10px; color: var(--on-surface-variant); }
.chart-x span { flex: 1; text-align: center; }
.mini-select { background: var(--surface-container-low); border: none; border-radius: 4px; font-size: 12px; padding: 4px 12px; color: var(--on-surface-variant); }

/* Side */
.pin-list { display: flex; flex-direction: column; gap: 16px; }
.pin-item { display: flex; align-items: center; gap: 16px; padding: 12px; background: var(--surface-container); border-radius: 8px; border-left: 4px solid var(--outline); }
.pin-item.active { border-left-color: var(--primary-bright); }
.pin-item p { margin: 0; color: var(--on-surface); }
.hole-chip { width: 48px; height: 48px; display: flex; flex-direction: column; align-items: center; justify-content: center; background: var(--surface-container-low); border-radius: 4px; border: 1px solid var(--outline-variant); }
.hole-chip .lbl { font-size: 10px; color: var(--on-surface-variant); }
.hole-chip .num { font-size: 20px; font-weight: 700; line-height: 1; }
.ghost-btn { width: 100%; margin-top: 24px; padding: 12px; border: 1px solid var(--outline-variant); background: none; border-radius: 8px; font-size: 12px; font-weight: 700; letter-spacing: .05em; color: var(--on-surface-variant); cursor: pointer; transition: background .2s; }
.ghost-btn:hover { background: var(--surface-bright); }
.icon-plain { background: none; border: none; cursor: pointer; }

.pkg-row { display: flex; justify-content: space-between; align-items: center; margin-top: 16px; }
.pkg-name { display: flex; align-items: center; gap: 12px; color: var(--on-surface); }
.pkg-badge { font-size: 12px; padding: 2px 8px; border-radius: 4px; display: inline-flex; align-items: center; gap: 8px; }
.pkg-badge.ok { color: var(--tertiary); background: rgba(104,219,169,.1); }
.pkg-badge.building { color: var(--primary-bright); }
.spinner { width: 12px; height: 12px; border: 2px solid var(--primary-bright); border-top-color: transparent; border-radius: 50%; animation: spin 1s linear infinite; }

.timeline { position: relative; padding-left: 24px; display: flex; flex-direction: column; gap: 24px; }
.timeline::before { content: ""; position: absolute; left: 5px; top: 8px; bottom: 8px; width: 2px; background: var(--outline-variant); }
.tl-item { position: relative; }
.tl-item p { margin: 0; font-size: 14px; color: var(--on-surface); }
.tl-item .sub { font-size: 11px; }
.tl-node { position: absolute; left: -24px; top: 4px; width: 12px; height: 12px; border-radius: 50%; box-shadow: 0 0 0 4px var(--surface-container-high); }
.tl-item.dim { opacity: .6; }
.struck { text-decoration: line-through; }

@media (max-width: 1100px) {
  .kpi-grid { grid-template-columns: repeat(2, 1fr); }
  .grid-12 { grid-template-columns: 1fr; }
}
@media (max-width: 640px) {
  .kpi-grid { grid-template-columns: 1fr; }
  .trust-grid { grid-template-columns: 1fr; gap: 24px; }
}
</style>
