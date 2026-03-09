/**
 * Delete choice modal: soft delete (discard) vs permanent delete (hard).
 * Trigger: [data-delete-choice] with data-delete-choice-soft-url and/or data-delete-choice-hard-url,
 *          data-delete-choice-title.
 */
(function () {
  function ready(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
    document.addEventListener("turbo:load", fn);
  }

  function setFormMethod(form, method) {
    if (!form) return;
    const normalized = (method || "post").toLowerCase();
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

  ready(function () {
    const modal = document.getElementById("deleteChoiceModal");
    const form = document.getElementById("deleteChoiceModalForm");
    const titleEl = document.getElementById("deleteChoiceModalTitle");
    const softRadio = document.querySelector('[data-delete-choice-radio="soft"]');
    const hardRadio = document.querySelector('[data-delete-choice-radio="hard"]');
    const softLabel = softRadio && softRadio.closest("label");
    const hardLabel = hardRadio && hardRadio.closest("label");
    const requireTextContainer = document.getElementById("deleteChoiceModalRequireTextContainer");
    const requireTextInput = document.getElementById("deleteChoiceModalRequireText");
    const requireTextError = document.getElementById("deleteChoiceModalRequireTextError");
    const cancelBtn = document.getElementById("deleteChoiceModalCancel");
    const confirmBtn = document.getElementById("deleteChoiceModalConfirm");
    const backdrop = document.querySelector("[data-delete-choice-backdrop]");

    const choicePrompt = document.getElementById("deleteChoiceModalPrompt");
    const radiosContainer = document.getElementById("deleteChoiceModalRadios");
    const messageEl = document.getElementById("deleteChoiceModalMessage");
    const state = { softUrl: null, hardUrl: null };

    function openModal() {
      if (!modal) return;
      modal.classList.remove("hidden");
    }

    function closeModal() {
      if (!modal) return;
      modal.classList.add("hidden");
      if (requireTextInput) requireTextInput.value = "";
      if (requireTextError) requireTextError.classList.add("hidden");
    }

    function updateRequireTextVisibility() {
      if (!requireTextContainer) return;
      if (hardRadio && hardRadio.checked) {
        requireTextContainer.classList.remove("hidden");
      } else {
        requireTextContainer.classList.add("hidden");
        if (requireTextError) requireTextError.classList.add("hidden");
      }
    }

    document.addEventListener(
      "click",
      function (e) {
        const trigger = e.target.closest("[data-delete-choice]");
        if (!trigger) return;
        e.preventDefault();
        e.stopPropagation();

        const softUrl = trigger.getAttribute("data-delete-choice-soft-url");
        const hardUrl = trigger.getAttribute("data-delete-choice-hard-url");
        const title = trigger.getAttribute("data-delete-choice-title") || "Delete?";
        const message = trigger.getAttribute("data-delete-choice-message") || "";
        const btnLabel = trigger.getAttribute("data-delete-choice-confirm-label") || "Delete";

        if (!softUrl && !hardUrl) return;

        state.softUrl = softUrl || null;
        state.hardUrl = hardUrl || null;

        if (titleEl) titleEl.textContent = title;
        if (confirmBtn) confirmBtn.textContent = btnLabel;
        if (messageEl) {
          if (message) {
            messageEl.textContent = message;
            messageEl.classList.remove("hidden");
          } else {
            messageEl.classList.add("hidden");
          }
        }

        if (softLabel) {
          if (state.softUrl) {
            softLabel.style.display = "";
            if (softRadio) softRadio.disabled = false;
          } else {
            softLabel.style.display = "none";
            if (softRadio) softRadio.disabled = true;
          }
        }
        if (hardLabel) {
          if (state.hardUrl) {
            hardLabel.style.display = "";
            if (hardRadio) hardRadio.disabled = false;
          } else {
            hardLabel.style.display = "none";
            if (hardRadio) hardRadio.disabled = true;
          }
        }

        if (softRadio && hardRadio) {
          if (state.softUrl && state.hardUrl) {
            softRadio.checked = true;
          } else if (state.softUrl) {
            softRadio.checked = true;
          } else {
            hardRadio.checked = true;
          }
        }

        var singleOption = (state.softUrl && !state.hardUrl) || (!state.softUrl && state.hardUrl);
        if (choicePrompt) choicePrompt.style.display = singleOption ? "none" : "";
        if (radiosContainer) radiosContainer.style.display = singleOption ? "none" : "";

        updateRequireTextVisibility();
        if (singleOption && state.hardUrl) {
          if (requireTextContainer) requireTextContainer.classList.remove("hidden");
        }
        openModal();
      },
      true
    );

    if (softRadio) softRadio.addEventListener("change", updateRequireTextVisibility);
    if (hardRadio) hardRadio.addEventListener("change", updateRequireTextVisibility);

    if (cancelBtn) cancelBtn.addEventListener("click", closeModal);
    if (backdrop) backdrop.addEventListener("click", closeModal);

    if (confirmBtn && form) {
      confirmBtn.addEventListener("click", function () {
        const isHard = hardRadio && hardRadio.checked && state.hardUrl;

        if (isHard) {
          if (!requireTextInput || requireTextInput.value.trim() !== "DELETE") {
            if (requireTextError) requireTextError.classList.remove("hidden");
            if (requireTextInput) requireTextInput.focus();
            return;
          }
        }

        if (requireTextError) requireTextError.classList.add("hidden");

        const url = isHard ? state.hardUrl : state.softUrl;
        if (!url) return;

        form.setAttribute("action", url);
        setFormMethod(form, "delete");

        const tokenMeta = document.querySelector('meta[name="csrf-token"]');
        const token = tokenMeta && tokenMeta.getAttribute("content");
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

        closeModal();
        form.submit();
      });
    }
  });
})();
