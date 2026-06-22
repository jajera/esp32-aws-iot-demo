import "./style.css";
import { bar, sparkline } from "./charts.js";
import {
  fmtBytes,
  fmtFlash,
  fmtOffsetMs,
  fmtRelative,
  fmtTs,
  fmtUptime,
  heapMeta,
  signalMeta,
  tempMeta,
  wifiStatusLabel,
} from "./format.js";
import { initTheme, themeToggleMarkup, toggleTheme } from "./theme.js";

initTheme();

const apiBase = (import.meta.env.VITE_API_URL || "").replace(/\/$/, "");
const pollMs = Number(import.meta.env.VITE_POLL_INTERVAL_MS || 15000);
const defaultDevice = import.meta.env.VITE_DEFAULT_DEVICE_ID || "esp32-c";
const historyLimit = 30;

const state = {
  polling: true,
  loading: false,
  history: { rssi: [], temp: [], heap: [] },
  countdown: pollMs / 1000,
};

const app = document.querySelector("#app");
app.innerHTML = `
  <div class="app">
    <header class="topbar">
      <div class="brand">
        <div class="brand-icon" aria-hidden="true">
          <img src="/favicon.svg" width="28" height="28" alt="" />
        </div>
        <div>
          <h1>ESP32 Dashboard</h1>
          <p class="subtle">Live telemetry &amp; events via Query API</p>
        </div>
      </div>
      <div class="toolbar">
        <label class="field">
          <span>Device</span>
          <input id="deviceId" value="${defaultDevice}" placeholder="Thing name" autocomplete="off" />
        </label>
        ${themeToggleMarkup()}
        <button id="refresh" type="button">Refresh</button>
        <button id="togglePoll" type="button" class="ghost" aria-pressed="true">Auto 15s</button>
      </div>
    </header>

    <div id="banner" class="banner hidden"></div>

    <section class="status-row">
      <div id="livePill" class="pill muted">Waiting</div>
      <div id="status" class="status subtle">Waiting for first fetch…</div>
    </section>

    <section id="stats" class="stats-grid">
      ${statTile("signal", "Signal", "—", "dBm", "muted")}
      ${statTile("temp", "Chip temp", "—", "°C", "muted")}
      ${statTile("heap", "Free heap", "—", "", "muted")}
      ${statTile("uptime", "Uptime", "—", "", "muted")}
    </section>

    <section class="main-grid">
      <article class="panel">
        <div class="panel-head">
          <h2>Latest telemetry</h2>
          <span id="telemetryAge" class="chip muted">—</span>
        </div>
        <div id="telemetryDetail" class="detail-grid subtle">No data yet.</div>
        <div class="spark-row">
          <div><span class="spark-label">RSSI trend</span><div id="rssiSpark"></div></div>
          <div><span class="spark-label">Temp trend</span><div id="tempSpark"></div></div>
        </div>
      </article>

      <div class="side-stack">
        <article class="panel">
          <div class="panel-head">
            <h2>Device &amp; network</h2>
          </div>
          <div id="deviceNetworkDetail" class="detail-grid subtle">No data yet.</div>
        </article>

        <article class="panel">
          <div class="panel-head">
            <h2>Recent events</h2>
            <span id="eventCount" class="chip muted">0</span>
          </div>
          <div id="eventsCard" class="timeline subtle">No events yet.</div>
        </article>
      </div>
    </section>

    <footer class="footer subtle">
      <span id="apiHint">${apiBase ? apiBase : "VITE_API_URL not set"}</span>
    </footer>
  </div>
`;

function statTile(id, label, value, unit, tone) {
  return `
    <article class="stat ${tone}" data-stat="${id}">
      <div class="stat-label">${label}</div>
      <div class="stat-value">${value}<small>${unit ? ` ${unit}` : ""}</small></div>
      <div class="stat-meta" id="${id}Meta">—</div>
      <div id="${id}Bar"></div>
    </article>
  `;
}

const els = {
  banner: document.querySelector("#banner"),
  status: document.querySelector("#status"),
  livePill: document.querySelector("#livePill"),
  device: document.querySelector("#deviceId"),
  telemetryDetail: document.querySelector("#telemetryDetail"),
  deviceNetworkDetail: document.querySelector("#deviceNetworkDetail"),
  telemetryAge: document.querySelector("#telemetryAge"),
  eventsCard: document.querySelector("#eventsCard"),
  eventCount: document.querySelector("#eventCount"),
  rssiSpark: document.querySelector("#rssiSpark"),
  tempSpark: document.querySelector("#tempSpark"),
};

async function getJson(path) {
  const res = await fetch(`${apiBase}${path}`);
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(body.error || `${res.status} ${res.statusText}`);
  }
  return body;
}

function setBanner(message, tone = "error") {
  if (!message) {
    els.banner.classList.add("hidden");
    els.banner.textContent = "";
    return;
  }
  els.banner.className = `banner ${tone}`;
  els.banner.textContent = message;
}

function setLivePill(online, lastSeenTs) {
  if (!lastSeenTs) {
    els.livePill.className = "pill muted";
    els.livePill.textContent = "No data";
    return;
  }
  const ageSec = Math.floor(Date.now() / 1000) - lastSeenTs;
  const stale = ageSec > 120;
  els.livePill.className = `pill ${stale ? "warn" : "live"}`;
  els.livePill.textContent = stale ? `Stale · ${fmtRelative(lastSeenTs)}` : `Live · ${fmtRelative(lastSeenTs)}`;
}

function pushHistory(key, value) {
  if (value == null || Number.isNaN(value)) return;
  state.history[key].push(Number(value));
  if (state.history[key].length > historyLimit) {
    state.history[key].shift();
  }
}

function updateStat(id, value, unit, metaText, barHtml, tone) {
  const tile = document.querySelector(`[data-stat="${id}"]`);
  tile.className = `stat ${tone}`;
  tile.querySelector(".stat-value").innerHTML = `${value}<small>${unit ? ` ${unit}` : ""}</small>`;
  document.querySelector(`#${id}Meta`).textContent = metaText;
  document.querySelector(`#${id}Bar`).innerHTML = barHtml || "";
}

function detailRows(rows) {
  return rows
    .map(
      ([label, value]) =>
        `<div class="detail-row"><span>${label}</span><strong>${value}</strong></div>`
    )
    .join("");
}

function renderTelemetryDetail(t) {
  els.telemetryDetail.innerHTML = detailRows([
    ["Type", t.type ?? "—"],
    ["Timestamp", fmtTs(t.ts)],
    ["Device ID", t.device_id ?? "—"],
    ["RSSI", t.rssi != null ? `${t.rssi} dBm` : "—"],
    ["Heap free", fmtBytes(t.heap_free)],
    ["Uptime", fmtUptime(t.uptime_s)],
    ["Chip temp", t.chip_temp_c != null ? `${t.chip_temp_c} °C` : "—"],
  ]);
}

function renderDeviceNetworkDetail(t) {
  els.deviceNetworkDetail.innerHTML = detailRows([
    ["Chip model", t.chip_model || "—"],
    ["CPU", t.cpu_mhz != null ? `${t.cpu_mhz} MHz` : "—"],
    ["Flash", fmtFlash(t.flash_bytes)],
    ["Wi-Fi SSID", t.wifi_ssid || "—"],
    ["Wi-Fi status", wifiStatusLabel(t.wifi_status)],
    ["Channel", t.wifi_channel != null ? String(t.wifi_channel) : "—"],
    ["IP", t.wifi_ip || "—"],
    ["Gateway", t.wifi_gateway || "—"],
    ["DNS", t.wifi_dns || "—"],
    ["Clock offset", fmtOffsetMs(t.clock_offset_ms)],
  ]);
}

function renderEvents(events) {
  if (!events?.length) {
    els.eventsCard.innerHTML = `<div class="empty">No button events recorded yet.</div>`;
    els.eventCount.textContent = "0";
    return;
  }

  els.eventCount.textContent = String(events.length);
  els.eventsCard.innerHTML = events
    .map((event) => {
      const label = event.event || "event";
      const icon = event.type === "button" ? "●" : "◆";
      return `
        <div class="timeline-item">
          <div class="timeline-dot">${icon}</div>
          <div class="timeline-body">
            <div class="timeline-title">${label}</div>
            <div class="timeline-meta">${fmtTs(event.ts)} · ${fmtRelative(event.ts)} · ${event.type || "unknown"}</div>
          </div>
        </div>
      `;
    })
    .join("");
}

async function refresh() {
  const deviceId = els.device.value.trim();
  if (!deviceId) {
    setBanner("Enter a device id first.", "warn");
    return;
  }
  if (!apiBase) {
    setBanner("Missing VITE_API_URL build variable.", "error");
    return;
  }

  state.loading = true;
  els.status.textContent = `Loading ${deviceId}…`;
  setBanner("");

  const [telemetry, events] = await Promise.allSettled([
    getJson(`/devices/${encodeURIComponent(deviceId)}/telemetry/latest`),
    getJson(`/devices/${encodeURIComponent(deviceId)}/events?limit=20`),
  ]);

  let telemetryData = null;
  let eventsData = null;
  const errors = [];

  if (telemetry.status === "fulfilled") telemetryData = telemetry.value;
  else errors.push(`telemetry: ${telemetry.reason.message}`);

  if (events.status === "fulfilled") eventsData = events.value;
  else if (events.reason?.message?.includes("No events")) {
    eventsData = { events: [], count: 0 };
  } else {
    errors.push(`events: ${events.reason.message}`);
  }

  const t = telemetryData?.telemetry;
  const lastSeenTs = Math.max(
    telemetryData?.record?.effective_ts || t?.ts || 0,
    eventsData?.records?.[0]?.effective_ts || eventsData?.events?.[0]?.ts || 0
  );

  setLivePill(Boolean(lastSeenTs), lastSeenTs);

  if (t) {
    pushHistory("rssi", t.rssi);
    pushHistory("temp", t.chip_temp_c);
    pushHistory("heap", t.heap_free);

    const sig = signalMeta(t.rssi);
    updateStat("signal", t.rssi ?? "—", "dBm", sig.label, bar(sig.pct, sig.tone), sig.tone);

    const temp = tempMeta(t.chip_temp_c);
    const tempPct = t.chip_temp_c != null ? Math.min(100, (t.chip_temp_c / 85) * 100) : 0;
    updateStat(
      "temp",
      t.chip_temp_c ?? "—",
      "°C",
      temp.label,
      bar(tempPct, temp.tone),
      temp.tone
    );

    const heap = heapMeta(t.heap_free);
    updateStat(
      "heap",
      fmtBytes(t.heap_free),
      "",
      `${Math.round(heap.pct)}% free`,
      bar(heap.pct, heap.tone),
      heap.tone
    );

    updateStat("uptime", fmtUptime(t.uptime_s), "", "since boot", "", "good");

    renderTelemetryDetail(t);
    renderDeviceNetworkDetail(t);
    els.telemetryAge.textContent = fmtRelative(t.ts);
    els.rssiSpark.innerHTML = sparkline(state.history.rssi);
    els.tempSpark.innerHTML = sparkline(state.history.temp);
  } else {
    els.telemetryDetail.textContent = "No telemetry yet.";
    els.deviceNetworkDetail.textContent = "No telemetry yet.";
    els.telemetryAge.textContent = "—";
  }

  renderEvents(eventsData?.events || []);

  const now = new Date().toLocaleTimeString();
  els.status.textContent =
    errors.length > 0
      ? `Updated ${now} · partial data (${errors.join(" · ")})`
      : `Updated ${now} · polling every ${pollMs / 1000}s`;

  if (errors.length === 2) {
    setBanner(`Could not load data for ${deviceId}. ${errors.join(" · ")}`, "error");
  } else if (errors.length === 1) {
    setBanner(errors[0], "warn");
  }

  state.loading = false;
  state.countdown = pollMs / 1000;
}

function runRefresh() {
  return refresh().catch((error) => {
    setBanner(`Refresh failed: ${error.message}`, "error");
    els.status.textContent = `Refresh failed: ${error.message}`;
  });
}

document.querySelector("#refresh").addEventListener("click", runRefresh);

document.querySelector("#themeToggle").addEventListener("click", toggleTheme);

document.querySelector("#togglePoll").addEventListener("click", (event) => {
  state.polling = !state.polling;
  event.currentTarget.setAttribute("aria-pressed", String(state.polling));
  event.currentTarget.textContent = state.polling ? `Auto ${pollMs / 1000}s` : "Auto off";
  event.currentTarget.classList.toggle("ghost", state.polling);
  event.currentTarget.classList.toggle("active", !state.polling);
});

els.device.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    state.history = { rssi: [], temp: [], heap: [] };
    runRefresh();
  }
});

els.device.addEventListener("change", () => {
  state.history = { rssi: [], temp: [], heap: [] };
  runRefresh();
});

runRefresh();

setInterval(() => {
  if (!state.polling || state.loading) return;
  state.countdown -= 1;
  if (state.countdown <= 0) {
    runRefresh();
  }
}, 1000);
