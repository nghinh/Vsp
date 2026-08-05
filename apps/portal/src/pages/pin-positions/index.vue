<script setup lang="ts">
import { ref, computed } from "vue";
import { useRouter } from "vue-router";

const router = useRouter();

type Status = "Official" | "Scheduled" | "Expired" | "Selected";
interface Hole {
  num: number;
  par: number;
  status: Status;
  zone: string;
  yards: number;
}
const pars = [4, 4, 3, 5, 4, 4, 3, 4, 5, 4, 4, 3, 5, 4, 4, 3, 4, 5];
const holes = ref<Hole[]>(
  pars.map((par, i) => {
    const num = i + 1;
    let status: Status = num === 7 ? "Selected" : i < 5 ? "Official" : i % 3 === 0 ? "Scheduled" : "Expired";
    return { num, par, status, zone: "Center", yards: 200 + ((num * 7) % 90) };
  }),
);
const selected = ref(7);
const current = computed(() => holes.value.find((h) => h.num === selected.value)!);
const staleCount = computed(() => holes.value.filter((h) => h.status === "Expired").length);
const changedCount = computed(() => holes.value.filter((h) => h.status === "Scheduled" || h.status === "Selected").length);

function selectHole(n: number) {
  selected.value = n;
}

const conditions = ref({
  greenSpeed: 9.5,
  maintenance: "Normal Operations",
  firmness: 7.2,
  moisture: 24,
  cartPath: "90 Degrees",
  courseStatus: "Open",
  notes: "",
  effective: "2026-08-06T06:00",
  expiry: "2026-08-06T18:00",
});

const statusClass: Record<Status, string> = {
  Official: "st-official",
  Scheduled: "st-scheduled",
  Expired: "st-expired",
  Selected: "st-selected",
};
</script>

<template>
  <div class="pins">
    <header class="topline">
      <div>
        <nav class="crumbs mono">Portal <span class="material-symbols-outlined">chevron_right</span> BRG Legend Hill <span class="material-symbols-outlined">chevron_right</span> <span class="c-primary">Pin &amp; Conditions</span></nav>
      </div>
      <div class="topline-actions">
        <div class="seg">
          <button class="seg-btn active">TODAY</button>
          <button class="seg-btn">CALENDAR</button>
        </div>
        <button class="btn-primary"><span class="material-symbols-outlined">publish</span> PUBLISH OPERATIONS</button>
      </div>
    </header>

    <div class="layout">
      <!-- Hole grid -->
      <section class="grid-pane">
        <div class="hole-grid">
          <button
            v-for="h in holes"
            :key="h.num"
            class="hole-card"
            :class="{ sel: h.num === selected }"
            @click="selectHole(h.num)"
          >
            <div class="hole-top">
              <div><span class="hnum mono">#{{ h.num }}</span><span class="hpar">Par {{ h.par }}</span></div>
              <span class="hstatus" :class="statusClass[h.num === selected ? 'Selected' : h.status]">{{ h.num === selected ? "Selected" : h.status }}</span>
            </div>
            <div class="green-mini">
              <div class="dots"></div>
              <div class="green-ring"><span class="pin-dot"></span></div>
            </div>
            <div class="hole-foot mono"><span>Zone: {{ h.zone }}</span><span>{{ h.yards }} Yds</span></div>
          </button>
        </div>

        <div class="summary">
          <div class="summary-metrics">
            <div><p class="sm-lbl">Changes Detected</p><p class="sm-val mono c-primary">{{ changedCount.toString().padStart(2, "0") }} Holes</p></div>
            <div class="divider"></div>
            <div><p class="sm-lbl">Stale Pins</p><p class="sm-val mono c-error">{{ staleCount.toString().padStart(2, "0") }} Holes</p></div>
          </div>
          <div class="summary-actions">
            <button class="btn-outline">DISCARD ALL</button>
            <button class="btn-primary" @click="router.push('/courses/1/versions')">REVIEW &amp; PUBLISH</button>
          </div>
        </div>
      </section>

      <!-- Detail / conditions panel -->
      <aside class="detail-pane">
        <div class="detail-head">
          <h3><span class="c-primary">Hole {{ current.num }}</span> <span class="par-sub">· Par {{ current.par }}</span></h3>
          <div class="detail-tools">
            <button class="tool-btn"><span class="material-symbols-outlined">content_copy</span></button>
            <button class="tool-btn"><span class="material-symbols-outlined">delete</span></button>
          </div>
        </div>

        <div class="green-editor">
          <div class="dots"></div>
          <div class="zones"><span>Front</span><span>Center</span><span>Back</span></div>
          <div class="green-vector">
            <div class="pin-marker"><span class="material-symbols-outlined">location_on</span></div>
          </div>
          <div v-if="current.status === 'Expired' || current.status === 'Selected'" class="stale-tag"><span class="material-symbols-outlined">warning</span> PIN EXPIRED — UNOFFICIAL</div>
          <div class="coord mono">21.0285° N, 105.8542° E</div>
        </div>

        <div class="sched-grid">
          <div><label class="fl">Effective Time</label><input v-model="conditions.effective" class="fin mono" type="datetime-local" /></div>
          <div><label class="fl">Expiry Time</label><input v-model="conditions.expiry" class="fin mono" type="datetime-local" /></div>
        </div>
        <button class="btn-template"><span class="material-symbols-outlined">auto_fix_high</span> APPLY ZONE TEMPLATE</button>

        <div class="conditions">
          <h4 class="section-title">Course Global Conditions</h4>
          <div class="cond-grid">
            <div>
              <label class="fl">Green Speed</label>
              <div class="stimp"><input v-model.number="conditions.greenSpeed" class="fin-num mono" type="number" step="0.1" /><span class="mono unit">ft (Stimp)</span></div>
            </div>
            <div>
              <label class="fl">Maintenance</label>
              <select v-model="conditions.maintenance" class="fin"><option>Normal Operations</option><option>Aeration (Active)</option><option>Top Dressing</option></select>
            </div>
          </div>
          <div class="slider">
            <div class="slider-head"><label class="fl">Green Firmness</label><span class="mono c-primary">{{ conditions.firmness }} / 10</span></div>
            <input v-model.number="conditions.firmness" type="range" min="0" max="10" step="0.1" />
          </div>
          <div class="slider">
            <div class="slider-head"><label class="fl">Moisture Content</label><span class="mono c-primary">{{ conditions.moisture }}%</span></div>
            <input v-model.number="conditions.moisture" type="range" min="0" max="100" step="1" />
          </div>
          <div class="cond-grid">
            <div><label class="fl">Cart Path Status</label><select v-model="conditions.cartPath" class="fin"><option>90 Degrees</option><option>Cart Path Only</option><option>Freely Allowed</option></select></div>
            <div><label class="fl">Course Status</label><select v-model="conditions.courseStatus" class="fin"><option>Open</option><option>Delayed (Frost)</option><option>Closed</option></select></div>
          </div>
          <div><label class="fl">Operational Notes</label><textarea v-model="conditions.notes" class="fin" rows="3" placeholder="Add course-wide alerts here..."></textarea></div>
        </div>

        <button class="btn-publish"><span class="material-symbols-outlined">check_circle</span> SAVE &amp; PUBLISH UPDATES</button>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.pins { max-width: 1600px; }
.mono { font-family: var(--font-mono); }
.c-primary { color: var(--primary-bright); }
.c-error { color: var(--error); }

.topline { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; gap: 16px; flex-wrap: wrap; }
.crumbs { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--on-surface-variant); }
.crumbs .material-symbols-outlined { font-size: 14px; }
.topline-actions { display: flex; align-items: center; gap: 16px; }
.seg { display: flex; background: var(--surface-container-low); border-radius: 8px; padding: 4px; }
.seg-btn { padding: 6px 16px; background: none; border: none; border-radius: 6px; font-size: 12px; font-weight: 700; letter-spacing: .05em; color: var(--on-surface-variant); cursor: pointer; }
.seg-btn.active { background: var(--secondary-container); color: var(--on-secondary-container); }
.btn-primary { display: inline-flex; align-items: center; gap: 8px; background: var(--primary-container); color: #fff; border: none; padding: 10px 20px; border-radius: 999px; font-size: 12px; font-weight: 700; letter-spacing: .05em; cursor: pointer; }
.btn-primary:hover { filter: brightness(1.1); }

.layout { display: grid; grid-template-columns: minmax(0, 1fr) 460px; gap: 24px; }

.hole-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 16px; }
.hole-card { text-align: left; background: var(--surface-container); border: 1px solid rgba(90,65,56,.2); border-radius: 12px; padding: 16px; cursor: pointer; transition: border-color .2s; }
.hole-card:hover { border-color: rgba(255,181,153,.5); }
.hole-card.sel { border-color: var(--primary-bright); box-shadow: 0 0 0 1px var(--primary-bright); }
.hole-top { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px; }
.hnum { font-size: 24px; font-weight: 700; color: var(--on-surface); display: block; line-height: 1.1; }
.hpar { font-size: 12px; text-transform: uppercase; color: var(--on-surface-variant); }
.hstatus { padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 700; text-transform: uppercase; }
.st-official { background: rgba(104,219,169,.2); color: var(--tertiary); }
.st-scheduled { background: rgba(255,181,153,.2); color: var(--primary-bright); }
.st-expired { background: rgba(255,180,171,.2); color: var(--error); }
.st-selected { background: var(--secondary-container); color: var(--on-secondary-container); }
.green-mini { aspect-ratio: 1; background: var(--surface); border-radius: 8px; border: 1px solid rgba(90,65,56,.1); position: relative; overflow: hidden; margin-bottom: 8px; }
.dots { position: absolute; inset: 0; background-image: radial-gradient(rgba(255,255,255,.1) 1px, transparent 1px); background-size: 20px 20px; opacity: .3; }
.green-ring { position: absolute; inset: 16px; border-radius: 50%; border: 2px dashed rgba(104,219,169,.2); background: rgba(104,219,169,.05); display: grid; place-items: center; }
.pin-dot { width: 8px; height: 8px; background: var(--primary-bright); border-radius: 50%; }
.hole-foot { display: flex; justify-content: space-between; font-size: 12px; color: var(--on-surface-variant); }

.summary { margin-top: 24px; background: var(--surface-container-high); border: 1px solid rgba(90,65,56,.3); border-radius: 16px; padding: 24px; display: flex; justify-content: space-between; align-items: center; gap: 16px; flex-wrap: wrap; }
.summary-metrics { display: flex; gap: 32px; align-items: center; }
.sm-lbl { margin: 0 0 4px; font-size: 12px; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: var(--on-surface-variant); }
.sm-val { margin: 0; font-size: 24px; font-weight: 700; }
.divider { width: 1px; height: 48px; background: rgba(90,65,56,.2); }
.summary-actions { display: flex; gap: 16px; }
.btn-outline { height: 48px; padding: 0 24px; border-radius: 12px; border: 1px solid var(--outline-variant); background: none; color: var(--on-surface); font-size: 12px; font-weight: 700; letter-spacing: .05em; cursor: pointer; }
.btn-outline:hover { background: var(--surface-variant); }
.summary-actions .btn-primary { height: 48px; border-radius: 12px; }

/* Detail pane */
.detail-pane { background: var(--surface-container-low); border: 1px solid var(--border); border-radius: 16px; padding: 24px; align-self: start; }
.detail-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
.detail-head h3 { margin: 0; font-size: 24px; font-weight: 600; }
.par-sub { color: var(--on-surface-variant); font-size: 16px; font-weight: 400; }
.detail-tools { display: flex; gap: 8px; }
.tool-btn { padding: 8px; background: var(--surface-variant); border: none; border-radius: 8px; color: var(--on-surface-variant); cursor: pointer; }
.tool-btn:hover { color: var(--on-surface); }

.green-editor { position: relative; aspect-ratio: 1; background: var(--surface-container-lowest); border-radius: 16px; border: 1px solid rgba(90,65,56,.3); margin-bottom: 24px; overflow: hidden; }
.green-editor .dots { opacity: .4; }
.zones { position: absolute; inset: 0; display: flex; flex-direction: column; pointer-events: none; }
.zones span { flex: 1; display: flex; align-items: center; justify-content: center; font-size: 10px; text-transform: uppercase; font-weight: 700; color: rgba(255,181,153,.3); border-bottom: 1px dashed rgba(255,181,153,.2); }
.zones span:last-child { border-bottom: none; }
.green-vector { position: absolute; inset: 32px; border-radius: 50%; border: 4px solid rgba(104,219,169,.3); background: rgba(104,219,169,.05); }
.pin-marker { position: absolute; top: 25%; left: 50%; transform: translate(-50%, -50%); width: 28px; height: 28px; background: var(--primary-bright); border-radius: 50%; display: grid; place-items: center; box-shadow: 0 0 0 4px rgba(255,181,153,.2); }
.pin-marker .material-symbols-outlined { color: #fff; font-size: 16px; }
.stale-tag { position: absolute; top: 16px; left: 16px; background: rgba(147,0,10,.9); color: var(--on-error-container); padding: 4px 12px; border-radius: 999px; font-size: 10px; font-weight: 700; display: flex; align-items: center; gap: 4px; }
.stale-tag .material-symbols-outlined { font-size: 14px; }
.coord { position: absolute; bottom: 16px; left: 50%; transform: translateX(-50%); background: rgba(45,52,73,.9); padding: 4px 8px; border-radius: 4px; font-size: 12px; white-space: nowrap; }

.sched-grid, .cond-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px; }
.fl { display: block; font-size: 12px; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: var(--on-surface-variant); margin-bottom: 8px; }
.fin { width: 100%; background: var(--surface-variant); border: none; border-radius: 8px; padding: 10px 12px; color: var(--on-surface); font-size: 14px; }
.fin:focus { outline: 2px solid var(--primary-bright); }
.btn-template { width: 100%; height: 48px; background: var(--surface-variant); border: 1px solid rgba(255,181,153,.3); color: var(--primary-bright); border-radius: 12px; font-size: 12px; font-weight: 700; letter-spacing: .05em; display: flex; align-items: center; justify-content: center; gap: 8px; cursor: pointer; margin-bottom: 32px; }
.btn-template:hover { background: rgba(246,96,24,.1); }

.section-title { font-size: 12px; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; color: var(--on-surface-variant); border-bottom: 1px solid rgba(90,65,56,.1); padding-bottom: 8px; margin: 0 0 24px; }
.stimp { display: flex; align-items: center; gap: 12px; }
.fin-num { width: 80px; background: var(--surface-variant); border: none; border-radius: 8px; padding: 8px; color: var(--on-surface); font-size: 24px; font-weight: 700; }
.fin-num:focus { outline: 2px solid var(--primary-bright); }
.unit { color: var(--on-surface-variant); font-size: 13px; }
.slider { margin-bottom: 24px; }
.slider-head { display: flex; justify-content: space-between; margin-bottom: 8px; }
.slider input[type="range"] { width: 100%; accent-color: var(--primary-bright); }

.btn-publish { width: 100%; height: 56px; margin-top: 8px; background: var(--primary-container); color: #fff; border: none; border-radius: 12px; font-size: 18px; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 12px; cursor: pointer; box-shadow: 0 8px 20px rgba(0,0,0,.3); }
.btn-publish:hover { filter: brightness(1.1); }

@media (max-width: 1200px) { .layout { grid-template-columns: 1fr; } .detail-pane { max-width: 560px; } }
</style>
