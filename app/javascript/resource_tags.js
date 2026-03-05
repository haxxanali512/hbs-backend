/**
 * Resource tags input: type and press Tab/Enter to add a chip; chips are synced to a hidden field.
 * Runs on turbo:load and DOMContentLoaded so it works when navigating to the edit form via Turbo Drive.
 */
function initResourceTags() {
  const container = document.getElementById("resource-tags-container");
  const chipsEl = document.getElementById("resource-tags-chips");
  const input = document.getElementById("resource-tags-typeahead");
  const hidden = document.getElementById("resource_tags_hidden");
  if (!container || !chipsEl || !input || !hidden) return;
  if (container.getAttribute("data-tags-initialized") === "true") return;
  container.setAttribute("data-tags-initialized", "true");

  let tags = [];
  try {
    const raw = container.getAttribute("data-initial-tags");
    if (raw) tags = JSON.parse(raw);
    if (!Array.isArray(tags)) tags = [];
  } catch (e) {
    tags = [];
  }
  if (tags.length === 0 && hidden.value) {
    tags = hidden.value.split(",").map((s) => s.trim()).filter(Boolean);
  }

  function syncHidden() {
    hidden.value = tags.join(", ");
  }

  function renderChips() {
    chipsEl.innerHTML = "";
    tags.forEach((tag, i) => {
      const span = document.createElement("span");
      span.className =
        "inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800 border border-gray-200";
      span.textContent = tag;
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "ml-0.5 text-gray-500 hover:text-gray-700 focus:outline-none";
      btn.setAttribute("aria-label", "Remove tag");
      btn.innerHTML = "&times;";
      const idx = i;
      btn.addEventListener("click", () => {
        tags.splice(idx, 1);
        renderChips();
        syncHidden();
        input.focus();
      });
      span.appendChild(btn);
      chipsEl.appendChild(span);
    });
    syncHidden();
  }

  function addTagFromInput() {
    const val = (input.value || "").trim();
    if (val === "") return;
    if (tags.indexOf(val) === -1) tags.push(val);
    input.value = "";
    renderChips();
  }

  input.addEventListener("keydown", (e) => {
    if (e.key === "Tab" || e.key === "Enter") {
      e.preventDefault();
      addTagFromInput();
    }
    if (e.key === "Backspace" && input.value === "" && tags.length > 0) {
      tags.pop();
      renderChips();
      syncHidden();
    }
  });

  input.addEventListener("blur", () => {
    if ((input.value || "").trim() !== "") addTagFromInput();
  });

  renderChips();
}

window.initResourceTags = initResourceTags;
document.addEventListener("turbo:load", initResourceTags);
document.addEventListener("DOMContentLoaded", initResourceTags);
document.addEventListener("turbo:frame-load", initResourceTags);
