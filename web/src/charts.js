export function sparkline(values, width = 140, height = 36) {
  if (!values.length) {
    return `<svg viewBox="0 0 ${width} ${height}" class="sparkline" aria-hidden="true"></svg>`;
  }
  if (values.length === 1) {
    values = [values[0], values[0]];
  }
  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min || 1;
  const points = values
    .map((v, i) => {
      const x = (i / (values.length - 1)) * width;
      const y = height - 4 - ((v - min) / range) * (height - 8);
      return `${x},${y}`;
    })
    .join(" ");
  return `<svg viewBox="0 0 ${width} ${height}" class="sparkline" aria-hidden="true"><polyline points="${points}" /></svg>`;
}

export function bar(pct, tone = "good") {
  const clamped = Math.max(0, Math.min(100, pct));
  return `<div class="bar ${tone}"><span style="width:${clamped}%"></span></div>`;
}
