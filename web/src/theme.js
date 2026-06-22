const STORAGE_KEY = "esp32-dashboard-theme";

function getPreferredColorScheme() {
  return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function parsePreference(stored) {
  if (stored === "light" || stored === "dark") return stored;
  return "auto";
}

function getStoredPreference() {
  return parsePreference(localStorage.getItem(STORAGE_KEY));
}

function resolveTheme(preference) {
  if (preference === "auto") return getPreferredColorScheme();
  return preference;
}

function applyTheme(preference) {
  const effective = resolveTheme(preference);
  document.documentElement.dataset.theme = effective;
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) {
    meta.content = effective === "dark" ? "#0b1220" : "#f5f5f5";
  }
  return effective;
}

let preference = getStoredPreference();

export function initTheme() {
  applyTheme(preference);

  if (preference === "auto") {
    window.matchMedia("(prefers-color-scheme: light)").addEventListener("change", () => {
      if (preference === "auto") applyTheme("auto");
    });
  }
}

export function toggleTheme() {
  const effective = document.documentElement.dataset.theme;
  if (effective === "dark") {
    preference = "light";
  } else if (effective === "light") {
    preference = "dark";
  } else {
    preference = "auto";
  }

  applyTheme(preference);

  if (preference === "auto") {
    localStorage.removeItem(STORAGE_KEY);
  } else {
    localStorage.setItem(STORAGE_KEY, preference);
  }
}

export function themeToggleMarkup() {
  return `
    <button
      type="button"
      id="themeToggle"
      class="theme-toggle"
      aria-label="Select theme"
      aria-live="polite"
      title="Select theme"
    >
      <svg aria-hidden="true" height="16" viewBox="0 0 24 24" width="16">
        <mask class="moon" id="theme-toggle-mask">
          <rect x="0" y="0" width="100%" height="100%" fill="white" />
          <circle cx="24" cy="10" r="6" fill="black" />
        </mask>
        <circle class="sun" cx="12" cy="12" r="6" mask="url(#theme-toggle-mask)" />
        <g class="sun-beams" stroke="currentColor">
          <line x1="12" y1="1" x2="12" y2="3" />
          <line x1="12" y1="21" x2="12" y2="23" />
          <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
          <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
          <line x1="1" y1="12" x2="3" y2="12" />
          <line x1="21" y1="12" x2="23" y2="12" />
          <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
          <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
        </g>
      </svg>
    </button>
  `;
}
