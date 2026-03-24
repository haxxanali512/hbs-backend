const KEY = "hbs.sidebar.collapsed";
const MOBILE_KEY = "hbs.sidebar.mobile.open";

function applySidebarState(collapsed) {
  const sidebar = document.getElementById("app-sidebar");
  if (!sidebar) return;

  const collapseIcon = sidebar.querySelector('[data-sidebar-icon="collapse"]');
  const expandIcon = sidebar.querySelector('[data-sidebar-icon="expand"]');
  if (collapseIcon) collapseIcon.classList.toggle("hidden", collapsed);
  if (expandIcon) expandIcon.classList.toggle("hidden", !collapsed);
}

function setCollapsed(collapsed) {
  const body = document.body;
  const currentlyCollapsed = body.classList.contains("sidebar-collapsed");
  if (collapsed === currentlyCollapsed) {
    applySidebarState(collapsed);
    return;
  }

  // Phase 1: hide content first (prevents logo/nav squeezing)
  body.classList.add("sidebar-collapsing");
  applySidebarState(collapsed);

  if (collapsed) {
    // Next frame: actually collapse width
    requestAnimationFrame(() => {
      body.classList.add("sidebar-collapsed");
      // Remove collapsing shortly after animation starts
      setTimeout(() => body.classList.remove("sidebar-collapsing"), 220);
    });
  } else {
    // Expand width immediately, then fade content back in after the width transition
    body.classList.remove("sidebar-collapsed");
    setTimeout(() => body.classList.remove("sidebar-collapsing"), 220);
  }
}

function initSidebarCollapse() {
  const btn = document.getElementById("sidebar-collapse-toggle");
  const sidebar = document.getElementById("app-sidebar");
  if (!sidebar) return;

  if (sidebar.dataset.sidebarInitialized === "1") return;
  sidebar.dataset.sidebarInitialized = "1";

  if (btn) {
    if (btn.dataset.initialized !== "1") {
      btn.dataset.initialized = "1";
      const stored = localStorage.getItem(KEY);
      setCollapsed(stored === "1");

      btn.addEventListener("click", () => {
        const next = !document.body.classList.contains("sidebar-collapsed");
        localStorage.setItem(KEY, next ? "1" : "0");
        setCollapsed(next);
      });
    }
  }

  // Mobile off-canvas toggle
  const mobileBtn = document.getElementById("mobile-sidebar-toggle");
  const mobileOverlay = document.getElementById("mobile-sidebar-overlay");

  function setMobileOpen(open) {
    document.body.classList.toggle("mobile-sidebar-open", open);
    if (mobileBtn) mobileBtn.setAttribute("aria-expanded", open ? "true" : "false");
    localStorage.setItem(MOBILE_KEY, open ? "1" : "0");
  }

  if (mobileBtn && mobileBtn.dataset.initialized !== "1") {
    mobileBtn.dataset.initialized = "1";
    mobileBtn.addEventListener("click", () => {
      const open = !document.body.classList.contains("mobile-sidebar-open");
      setMobileOpen(open);
    });
  }

  if (mobileOverlay && mobileOverlay.dataset.initialized !== "1") {
    mobileOverlay.dataset.initialized = "1";
    mobileOverlay.addEventListener("click", () => setMobileOpen(false));
  }

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") setMobileOpen(false);
  });
}

document.addEventListener("turbo:load", initSidebarCollapse);
document.addEventListener("DOMContentLoaded", initSidebarCollapse);

