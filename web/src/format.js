export function fmtTs(ts) {
  if (!ts) return "—";
  return new Date(ts * 1000).toLocaleString();
}

export function fmtRelative(ts) {
  if (!ts) return "—";
  const diff = Math.floor(Date.now() / 1000) - ts;
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

export function fmtUptime(seconds) {
  if (seconds == null || Number.isNaN(seconds)) return "—";
  const s = Number(seconds);
  const days = Math.floor(s / 86400);
  const hours = Math.floor((s % 86400) / 3600);
  const mins = Math.floor((s % 3600) / 60);
  if (days > 0) return `${days}d ${hours}h ${mins}m`;
  if (hours > 0) return `${hours}h ${mins}m`;
  return `${mins}m ${s % 60}s`;
}

export function fmtBytes(bytes) {
  if (bytes == null) return "—";
  const n = Number(bytes);
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)} MB`;
  if (n >= 1000) return `${(n / 1000).toFixed(0)} KB`;
  return `${n} B`;
}

export function fmtFlash(bytes) {
  if (bytes == null) return "—";
  const mb = Number(bytes) / (1024 * 1024);
  return `${mb.toFixed(0)} MB`;
}

export function fmtOffsetMs(ms) {
  if (ms == null || ms === 0) return "0 ms";
  const n = Number(ms);
  if (Math.abs(n) >= 1000) return `${(n / 1000).toFixed(2)} s`;
  return `${n} ms`;
}

export function wifiStatusLabel(status) {
  const labels = {
    0: "Idle",
    1: "No SSID",
    2: "Scan completed",
    3: "Connected",
    4: "Connect failed",
    5: "Connection lost",
    6: "Disconnected",
  };
  if (status == null) return "—";
  return labels[status] ?? `Code ${status}`;
}

export function signalMeta(rssi) {
  if (rssi == null) return { label: "Unknown", pct: 0, tone: "muted" };
  const pct = Math.max(0, Math.min(100, ((rssi + 90) / 60) * 100));
  if (rssi >= -55) return { label: "Excellent", pct, tone: "good" };
  if (rssi >= -67) return { label: "Good", pct, tone: "good" };
  if (rssi >= -75) return { label: "Fair", pct, tone: "warn" };
  if (rssi >= -85) return { label: "Weak", pct, tone: "warn" };
  return { label: "Poor", pct, tone: "bad" };
}

export function tempMeta(temp) {
  if (temp == null) return { label: "Unknown", tone: "muted" };
  if (temp < 35) return { label: "Cool", tone: "good" };
  if (temp < 50) return { label: "Normal", tone: "good" };
  if (temp < 65) return { label: "Warm", tone: "warn" };
  return { label: "Hot", tone: "bad" };
}

export function heapMeta(heapFree) {
  if (heapFree == null) return { pct: 0, tone: "muted" };
  const assumedTotal = 320_000;
  const pct = Math.max(0, Math.min(100, (Number(heapFree) / assumedTotal) * 100));
  let tone = "good";
  if (pct < 25) tone = "bad";
  else if (pct < 45) tone = "warn";
  return { pct, tone };
}
