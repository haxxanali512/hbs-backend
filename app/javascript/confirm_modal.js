/**
 * Confirm modal: clicks on [data-confirm-url] open the modal; confirm submits the form.
 * Supports:
 * - data-confirm-url: required, form action
 * - data-confirm-method: optional HTTP verb (post/delete/patch...) via Rails _method
 * - data-confirm-message: modal title
 * - data-confirm-body: modal body text
 * - data-confirm-label: confirm button label
 * - data-confirm-require-text: if present, require user to type this value before confirming
 *
 * Uses fresh DOM lookups so it works after Turbo Drive navigations.
 */
let confirmModalBound = false;
let confirmRequiredText = null;

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

function setMethodOverride(form, method) {
  if (!form) return;
  const normalized = (method || "post").toLowerCase();

  // Rails method override: keep form POST, add/remove hidden _method.
  form.setAttribute("method", "post");

  let methodInput = form.querySelector('input[name="_method"]');
  if (normalized === "post") {
    if (methodInput) methodInput.remove();
    return;
  }

  if (!methodInput) {
    methodInput = document.createElement("input");
    methodInput.setAttribute("type", "hidden");
    methodInput.setAttribute("name", "_method");
    form.appendChild(methodInput);
  }
  methodInput.setAttribute("value", normalized);
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
    document.addEventListener(
      "click",
      (e) => {
        const trigger = e.target.closest("[data-confirm-url]");
        if (!trigger) return;
        e.preventDefault();

        const message = trigger.getAttribute("data-confirm-message");
        const body = trigger.getAttribute("data-confirm-body");
        const confirmLabel = trigger.getAttribute("data-confirm-label") || "Confirm";
        const method = trigger.getAttribute("data-confirm-method") || "post";
        const url = trigger.getAttribute("data-confirm-url");
        const requireText = trigger.getAttribute("data-confirm-require-text");
        if (!url) return;

        const titleEl = document.querySelector("#confirmModal h3");
        if (titleEl && message) titleEl.textContent = message;
        const bodyEl = document.querySelector("#confirmModal [data-confirm-body-target]");
        if (bodyEl) bodyEl.textContent = body || "This action cannot be undone.";

        const btn = document.getElementById("confirmModalConfirm");
        if (btn) btn.textContent = confirmLabel;

        // Handle optional \"type to confirm\" input
        const inputContainer = document.getElementById("confirmModalInputContainer");
        const inputEl = document.getElementById("confirmModalInput");
        const inputLabel = document.getElementById("confirmModalInputLabel");
        const inputError = document.getElementById("confirmModalInputError");
        confirmRequiredText = requireText && requireText.length > 0 ? requireText : null;
        if (inputContainer && inputEl && inputLabel) {
          if (confirmRequiredText) {
            inputContainer.classList.remove("hidden");
            inputLabel.textContent =
              trigger.getAttribute("data-confirm-input-label") ||
              `Type ${confirmRequiredText} to confirm.`;
            inputEl.value = "";
            inputEl.placeholder =
              trigger.getAttribute("data-confirm-input-placeholder") || confirmRequiredText;
            if (inputError) inputError.classList.add("hidden");
          } else {
            inputContainer.classList.add("hidden");
          }
        }

        setMethodOverride(form, method);
        openConfirmModal(url);
      },
      true
    );
  }

  cancelBtn?.addEventListener("click", closeConfirmModal);
  confirmBtn?.addEventListener("click", () => {
    const form = document.getElementById("confirmModalForm");
    if (form) {
      // If a specific text is required, enforce it before submitting
      if (confirmRequiredText) {
        const inputEl = document.getElementById("confirmModalInput");
        const inputError = document.getElementById("confirmModalInputError");
        if (!inputEl || inputEl.value.trim() !== confirmRequiredText) {
          if (inputError) {
            inputError.classList.remove("hidden");
          } else {
            alert(`Please type ${confirmRequiredText} to confirm.`);
          }
          if (inputEl) inputEl.focus();
          return;
        }
      }

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
