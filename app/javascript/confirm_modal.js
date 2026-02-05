/**
 * Confirm modal: clicks on [data-confirm-url] open the modal; confirm submits the form (POST).
 * Uses fresh DOM lookups so it works after Turbo Drive navigations.
 */
let confirmModalBound = false;

function openConfirmModal(url) {
  const modal = document.getElementById("confirmModal");
  const form = document.getElementById("confirmModalForm");
  if (!modal || !form) return;
  form.setAttribute("action", url);
  modal.classList.remove("hidden");
  modal.classList.add("flex");
}

function closeConfirmModal() {
  const modal = document.getElementById("confirmModal");
  if (modal) {
    modal.classList.add("hidden");
    modal.classList.remove("flex");
  }
}

function bindConfirmModalListeners() {
  const modal = document.getElementById("confirmModal");
  const form = document.getElementById("confirmModalForm");
  const cancelBtn = document.getElementById("confirmModalCancel");
  const confirmBtn = document.getElementById("confirmModalConfirm");
  if (!modal || !form) return;

  window.HBSConfirm = { open: openConfirmModal, close: closeConfirmModal };

  if (!confirmModalBound) {
    confirmModalBound = true;
    document.addEventListener("click", (e) => {
      const trigger = e.target.closest("[data-confirm-url]");
      if (!trigger) return;
      e.preventDefault();
      const message = trigger.getAttribute("data-confirm-message");
      const confirmLabel = trigger.getAttribute("data-confirm-label") || "Confirm";
      const url = trigger.getAttribute("data-confirm-url");
      if (!url) return;
      const titleEl = document.querySelector("#confirmModal h3");
      if (titleEl && message) titleEl.textContent = message;
      const btn = document.getElementById("confirmModalConfirm");
      if (btn) btn.textContent = confirmLabel;
      openConfirmModal(url);
    }, true);
  }

  cancelBtn?.addEventListener("click", closeConfirmModal);
  confirmBtn?.addEventListener("click", () => {
    const form = document.getElementById("confirmModalForm");
    if (form) {
      const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content");
      if (token) {
        let input = form.querySelector('input[name="authenticity_token"]');
        if (!input) {
          input = document.createElement("input");
          input.setAttribute("type", "hidden");
          input.setAttribute("name", "authenticity_token");
          form.appendChild(input);
        }
        input.setAttribute("value", token);
      }
      form.submit();
    }
    closeConfirmModal();
  });
  modal.addEventListener("click", (e) => {
    if (e.target === modal) closeConfirmModal();
  });
}

function initConfirmModal() {
  bindConfirmModalListeners();
}

document.addEventListener("DOMContentLoaded", initConfirmModal);
document.addEventListener("turbo:load", initConfirmModal);
