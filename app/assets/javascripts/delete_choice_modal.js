// Delete choice modal: soft delete (discard) vs permanent delete (hard).
// Trigger: element with data-delete-choice, data-delete-choice-soft-url, data-delete-choice-hard-url (optional),
//         data-delete-choice-title.
// If only one URL is provided, only that option is shown.

(function() {
  function ready(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
    document.addEventListener('turbo:load', fn);
  }

  function setFormMethod(form, method) {
    if (!form) return;
    var normalized = (method || 'post').toLowerCase();
    form.setAttribute('method', 'post');
    var methodInput = form.querySelector('input[name="_method"]');
    if (normalized === 'post') {
      if (methodInput) methodInput.parentNode.removeChild(methodInput);
      return;
    }
    if (!methodInput) {
      methodInput = document.createElement('input');
      methodInput.setAttribute('type', 'hidden');
      methodInput.setAttribute('name', '_method');
      form.appendChild(methodInput);
    }
    methodInput.setAttribute('value', normalized);
  }

  ready(function() {
    var modal = document.getElementById('deleteChoiceModal');
    var form = document.getElementById('deleteChoiceModalForm');
    var titleEl = document.getElementById('deleteChoiceModalTitle');
    var softRadio = document.querySelector('[data-delete-choice-radio="soft"]');
    var hardRadio = document.querySelector('[data-delete-choice-radio="hard"]');
    var softLabel = softRadio && softRadio.closest('label');
    var hardLabel = hardRadio && hardRadio.closest('label');
    var requireTextContainer = document.getElementById('deleteChoiceModalRequireTextContainer');
    var requireTextInput = document.getElementById('deleteChoiceModalRequireText');
    var requireTextError = document.getElementById('deleteChoiceModalRequireTextError');
    var cancelBtn = document.getElementById('deleteChoiceModalCancel');
    var confirmBtn = document.getElementById('deleteChoiceModalConfirm');
    var backdrop = document.querySelector('[data-delete-choice-backdrop]');

    var state = { softUrl: null, hardUrl: null };

    function openModal() {
      if (!modal) return;
      modal.classList.remove('hidden');
    }

    function closeModal() {
      if (!modal) return;
      modal.classList.add('hidden');
      if (requireTextInput) requireTextInput.value = '';
      if (requireTextError) requireTextError.classList.add('hidden');
    }

    function updateRequireTextVisibility() {
      if (!requireTextContainer) return;
      if (hardRadio && hardRadio.checked) {
        requireTextContainer.classList.remove('hidden');
      } else {
        requireTextContainer.classList.add('hidden');
        if (requireTextError) requireTextError.classList.add('hidden');
      }
    }

    document.addEventListener('click', function(e) {
      var trigger = e.target.closest('[data-delete-choice]');
      if (!trigger) return;
      e.preventDefault();

      var softUrl = trigger.getAttribute('data-delete-choice-soft-url');
      var hardUrl = trigger.getAttribute('data-delete-choice-hard-url');
      var title = trigger.getAttribute('data-delete-choice-title') || 'Delete?';

      if (!softUrl && !hardUrl) return;

      state.softUrl = softUrl || null;
      state.hardUrl = hardUrl || null;

      if (titleEl) titleEl.textContent = title;

      if (softLabel) {
        if (state.softUrl) {
          softLabel.style.display = '';
          if (softRadio) softRadio.disabled = false;
        } else {
          softLabel.style.display = 'none';
          if (softRadio) softRadio.disabled = true;
        }
      }
      if (hardLabel) {
        if (state.hardUrl) {
          hardLabel.style.display = '';
          if (hardRadio) hardRadio.disabled = false;
        } else {
          hardLabel.style.display = 'none';
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

      updateRequireTextVisibility();
      openModal();
    }, true);

    if (softRadio) softRadio.addEventListener('change', updateRequireTextVisibility);
    if (hardRadio) hardRadio.addEventListener('change', updateRequireTextVisibility);

    if (cancelBtn) cancelBtn.addEventListener('click', closeModal);
    if (backdrop) backdrop.addEventListener('click', closeModal);

    if (confirmBtn && form) {
      confirmBtn.addEventListener('click', function() {
        var isHard = hardRadio && hardRadio.checked && state.hardUrl;

        if (isHard) {
          if (!requireTextInput || requireTextInput.value.trim() !== 'DELETE') {
            if (requireTextError) {
              requireTextError.classList.remove('hidden');
            }
            if (requireTextInput) requireTextInput.focus();
            return;
          }
        }

        if (requireTextError) requireTextError.classList.add('hidden');

        var url = isHard ? state.hardUrl : state.softUrl;
        if (!url) return;

        form.setAttribute('action', url);
        setFormMethod(form, 'delete');

        var tokenMeta = document.querySelector('meta[name="csrf-token"]');
        var token = tokenMeta && tokenMeta.getAttribute('content');
        if (token) {
          var input = form.querySelector('input[name="authenticity_token"]');
          if (!input) {
            input = document.createElement('input');
            input.setAttribute('type', 'hidden');
            input.setAttribute('name', 'authenticity_token');
            form.appendChild(input);
          }
          input.setAttribute('value', token);
        }

        closeModal();
        form.submit();
      });
    }
  });
})();
