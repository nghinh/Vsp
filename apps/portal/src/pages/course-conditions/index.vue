<script setup lang="ts">
import { ref } from "vue";

const cond = ref({
  greenSpeed: 9.5,
  maintenance: "Normal Operations",
  firmness: 7.2,
  moisture: 24,
  cartPath: "90 Degrees",
  courseStatus: "Open",
  notes: "",
});

const courses = ["BRG Legend Hill · Course A", "BRG Legend Hill · Course B", "Kings Island · Mountain"];
const selectedCourse = ref(courses[0]);

const summary = [
  { icon: "speed", label: "Green Speed (Stimp)", value: "9.5 ft", tone: "c-tertiary", state: "Đã cập nhật" },
  { icon: "grass", label: "Green Firmness", value: "7.2 / 10", tone: "c-tertiary", state: "Đã cập nhật" },
  { icon: "water_drop", label: "Moisture", value: "24%", tone: "c-primary", state: "Chờ kiểm tra" },
  { icon: "directions_car", label: "Cart Path", value: "90 Degrees", tone: "c-tertiary", state: "Áp dụng" },
];

const saving = ref(false);
const saved = ref(false);
function save() {
  saving.value = true;
  setTimeout(() => {
    saving.value = false;
    saved.value = true;
    setTimeout(() => (saved.value = false), 2500);
  }, 500);
}
</script>

<template>
  <div class="conditions-page">
    <header class="page-head">
      <div>
        <nav class="crumbs mono">Portal <span class="material-symbols-outlined">chevron_right</span> BRG Legend Hill <span class="material-symbols-outlined">chevron_right</span> <span class="c-primary">Conditions</span></nav>
        <h2>Tình trạng sân</h2>
      </div>
      <select v-model="selectedCourse" class="course-sel"><option v-for="c in courses" :key="c">{{ c }}</option></select>
    </header>

    <div class="summary-grid">
      <div v-for="s in summary" :key="s.label" class="summary-card">
        <span class="material-symbols-outlined" :class="s.tone">{{ s.icon }}</span>
        <div>
          <p class="sc-label">{{ s.label }}</p>
          <p class="sc-value mono">{{ s.value }}</p>
        </div>
        <span class="sc-state" :class="s.tone">{{ s.state }}</span>
      </div>
    </div>

    <div class="editor-card">
      <h3 class="section-title">Course Global Conditions</h3>
      <div class="cond-grid">
        <div>
          <label class="fl">Green Speed</label>
          <div class="stimp"><input v-model.number="cond.greenSpeed" class="fin-num mono" type="number" step="0.1" /><span class="unit mono">ft (Stimpmeter)</span></div>
        </div>
        <div>
          <label class="fl">Maintenance</label>
          <select v-model="cond.maintenance" class="fin"><option>Normal Operations</option><option>Aeration (Active)</option><option>Top Dressing</option></select>
        </div>
      </div>

      <div class="slider">
        <div class="slider-head"><label class="fl">Green Firmness</label><span class="mono c-primary">{{ cond.firmness }} / 10</span></div>
        <input v-model.number="cond.firmness" type="range" min="0" max="10" step="0.1" />
      </div>
      <div class="slider">
        <div class="slider-head"><label class="fl">Moisture Content</label><span class="mono c-primary">{{ cond.moisture }}%</span></div>
        <input v-model.number="cond.moisture" type="range" min="0" max="100" step="1" />
      </div>

      <div class="cond-grid">
        <div><label class="fl">Cart Path Status</label><select v-model="cond.cartPath" class="fin"><option>90 Degrees</option><option>Cart Path Only</option><option>Freely Allowed</option></select></div>
        <div><label class="fl">Course Status</label><select v-model="cond.courseStatus" class="fin"><option>Open</option><option>Delayed (Frost)</option><option>Closed</option></select></div>
      </div>
      <div><label class="fl">Operational Notes</label><textarea v-model="cond.notes" class="fin" rows="3" placeholder="Add course-wide alerts here..."></textarea></div>

      <div class="editor-actions">
        <span v-if="saved" class="saved-msg mono"><span class="material-symbols-outlined">check_circle</span> Đã lưu &amp; công bố</span>
        <button class="btn-publish" :disabled="saving" @click="save"><span class="material-symbols-outlined">check_circle</span> {{ saving ? "ĐANG LƯU…" : "SAVE & PUBLISH UPDATES" }}</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.conditions-page { max-width: 900px; }
.mono { font-family: var(--font-mono); }
.c-primary { color: var(--primary-bright); }
.c-tertiary { color: var(--tertiary); }

.page-head { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 32px; gap: 16px; flex-wrap: wrap; }
.crumbs { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--on-surface-variant); }
.crumbs .material-symbols-outlined { font-size: 14px; }
.page-head h2 { margin: 4px 0 0; font-size: 24px; font-weight: 600; }
.course-sel { background: var(--surface-container-high); border: 1px solid var(--outline-variant); border-radius: 999px; padding: 8px 16px; color: var(--on-surface); }

.summary-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }
.summary-card { background: var(--surface-container); border: 1px solid var(--border); border-radius: 12px; padding: 16px; display: flex; align-items: center; gap: 12px; }
.summary-card > .material-symbols-outlined { font-size: 28px; }
.sc-label { margin: 0; font-size: 11px; text-transform: uppercase; letter-spacing: .05em; color: var(--on-surface-variant); }
.sc-value { margin: 2px 0 0; font-size: 18px; font-weight: 700; }
.sc-state { margin-left: auto; font-size: 10px; font-weight: 700; text-transform: uppercase; }

.editor-card { background: var(--surface-container-high); border: 1px solid var(--border); border-radius: 16px; padding: 32px; }
.section-title { font-size: 12px; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; color: var(--on-surface-variant); border-bottom: 1px solid rgba(90,65,56,.2); padding-bottom: 12px; margin: 0 0 24px; }
.cond-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 24px; }
.fl { display: block; font-size: 12px; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: var(--on-surface-variant); margin-bottom: 8px; }
.fin { width: 100%; background: var(--surface-variant); border: none; border-radius: 8px; padding: 12px; color: var(--on-surface); font-size: 14px; }
.fin:focus { outline: 2px solid var(--primary-bright); }
.stimp { display: flex; align-items: center; gap: 12px; }
.fin-num { width: 96px; background: var(--surface-variant); border: none; border-radius: 8px; padding: 8px 12px; color: var(--on-surface); font-size: 24px; font-weight: 700; }
.fin-num:focus { outline: 2px solid var(--primary-bright); }
.unit { color: var(--on-surface-variant); font-size: 13px; }
.slider { margin-bottom: 24px; }
.slider-head { display: flex; justify-content: space-between; margin-bottom: 8px; }
.slider input[type="range"] { width: 100%; accent-color: var(--primary-bright); }
.editor-actions { display: flex; align-items: center; justify-content: flex-end; gap: 16px; margin-top: 16px; }
.saved-msg { display: inline-flex; align-items: center; gap: 6px; color: var(--tertiary); font-size: 13px; }
.saved-msg .material-symbols-outlined { font-size: 18px; }
.btn-publish { height: 52px; padding: 0 32px; background: var(--primary-container); color: #fff; border: none; border-radius: 12px; font-size: 16px; font-weight: 600; display: flex; align-items: center; gap: 12px; cursor: pointer; }
.btn-publish:hover { filter: brightness(1.1); }
.btn-publish:disabled { opacity: .6; cursor: not-allowed; }

@media (max-width: 900px) { .summary-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 560px) { .summary-grid { grid-template-columns: 1fr; } .cond-grid { grid-template-columns: 1fr; } }
</style>
