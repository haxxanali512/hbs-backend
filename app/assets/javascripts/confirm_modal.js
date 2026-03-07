// Sprockets-driven confirm modal script.
// Supports:
// - data-confirm-url          : required, form action
// - data-confirm-method       : HTTP verb (post/delete/patch...) via Rails _method override
// - data-confirm-message      : modal title
// - data-confirm-body         : modal body text
// - data-confirm-label        : confirm button label
// - data-confirm-require-text : if present, require user to type this value before confirming

(function() {
  function ready(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
    document.addEventListener('turbo:load', fn);
  }

  function setMethodOverride(form, method) {
    if (!form) return;
    var normalized = (method || 'post').toLowerCase();
    form.setAttribute('method', 'post');

    var methodInput = form.querySelector('input[name=\"_method\"]');
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
    var modal = document.getElementById('confirmModal');
    var form  = document.getElementById('confirmModalForm');
    var cancelBtn = document.getElementById('confirmModalCancel');
    var confirmBtn = document.getElementById('confirmModalConfirm');
    var confirmRequiredText = null;

    function openModal(url) {
      if (!modal || !form) return;
      form.setAttribute('action', url);
      modal.classList.remove('hidden');
      modal.classList.add('flex');
    }

    function closeModal() {
      if (!modal) return;
      modal.classList.add('hidden');
      modal.classList.remove('flex');
    }

    window.HBSConfirm = { open: openModal, close: closeModal };

    document.addEventListener('click', function(e) {
      var trigger = e.target.closest('[data-confirm-url]');
      if (!trigger) return;
      e.preventDefault();

      var message      = trigger.getAttribute('data-confirm-message');
      var body         = trigger.getAttribute('data-confirm-body');
      var confirmLabel = trigger.getAttribute('data-confirm-label') || 'Confirm';
      var method       = trigger.getAttribute('data-confirm-method') || 'post';
      var url          = trigger.getAttribute('data-confirm-url');
      var requireText  = trigger.getAttribute('data-confirm-require-text');
      if (!url) return;

      var titleEl = document.querySelector('#confirmModal h3');
      if (titleEl && message) { titleEl.textContent = message; }
      var bodyEl = document.querySelector('#confirmModal [data-confirm-body-target]');
      if (bodyEl) { bodyEl.textContent = body || 'This action cannot be undone.'; }

      var btn = document.getElementById('confirmModalConfirm');
      if (btn) { btn.textContent = confirmLabel; }

      // Handle optional \"type to confirm\" input
      var inputContainer = document.getElementById('confirmModalInputContainer');
      var inputEl        = document.getElementById('confirmModalInput');
      var inputLabel     = document.getElementById('confirmModalInputLabel');
      var inputError     = document.getElementById('confirmModalInputError');
      confirmRequiredText = (requireText && requireText.length > 0) ? requireText : null;
      if (inputContainer && inputEl && inputLabel) {
        if (confirmRequiredText) {
          inputContainer.classList.remove('hidden');
          inputLabel.textContent =
            trigger.getAttribute('data-confirm-input-label') ||
            ('Type ' + confirmRequiredText + ' to confirm.');
          inputEl.value = '';
          inputEl.placeholder =
            trigger.getAttribute('data-confirm-input-placeholder') || confirmRequiredText;
          if (inputError) inputError.classList.add('hidden');
        } else {
          inputContainer.classList.add('hidden');
        }
      }

      setMethodOverride(form, method);
      openModal(url);
    }, true);

    if (cancelBtn) {
      cancelBtn.addEventListener('click', closeModal);
    }

    if (confirmBtn) {
      confirmBtn.addEventListener('click', function() {
        if (!form) { closeModal(); return; }

        // Enforce required text if any
        if (confirmRequiredText) {
          var inputEl  = document.getElementById('confirmModalInput');
          var inputErr = document.getElementById('confirmModalInputError');
          if (!inputEl || inputEl.value.trim() !== confirmRequiredText) {
            if (inputErr) inputErr.classList.remove('hidden');
            else alert('Please type ' + confirmRequiredText + ' to confirm.');
            if (inputEl) inputEl.focus();
            return;
          }
        }

        // Add CSRF token if missing
        var tokenMeta = document.querySelector('meta[name=\"csrf-token\"]');
        var token     = tokenMeta && tokenMeta.getAttribute('content');
        if (token) {
          var input = form.querySelector('input[name=\"authenticity_token\"]');
          if (!input) {
            input = document.createElement('input');
            input.setAttribute('type', 'hidden');
            input.setAttribute('name', 'authenticity_token');
            form.appendChild(input);
          }
          input.setAttribute('value', token);
        }

        form.submit();
        closeModal();
      });
    }

    if (modal) {
      modal.addEventListener('click', function(e) {
        if (e.target === modal) { closeModal(); }
      });
    }
  });
})();

