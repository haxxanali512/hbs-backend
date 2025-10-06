(function(){
  function ready(fn){
    if(document.readyState === 'loading'){
      document.addEventListener('DOMContentLoaded', fn);
    } else { fn(); }
    document.addEventListener('turbo:load', fn);
  }

  ready(function(){
    var modal = document.getElementById('confirmModal');
    var form  = document.getElementById('confirmModalForm');
    var cancelBtn = document.getElementById('confirmModalCancel');
    var confirmBtn = document.getElementById('confirmModalConfirm');

    function openModal(url){
      if(!modal || !form) return;
      form.setAttribute('action', url);
      modal.classList.remove('hidden');
      modal.classList.add('flex');
    }
    function closeModal(){
      if(!modal) return;
      modal.classList.add('hidden');
      modal.classList.remove('flex');
    }

    window.HBSConfirm = { open: openModal, close: closeModal };

    document.addEventListener('click', function(e){
      var trigger = e.target.closest('[data-confirm-url]');
      if(trigger){
        e.preventDefault();
        var message = trigger.getAttribute('data-confirm-message');
        var confirmLabel = trigger.getAttribute('data-confirm-label') || 'Confirm';
        var url = trigger.getAttribute('data-confirm-url');
        if(url){
          // update modal copy & confirm label if provided
          var titleEl = document.querySelector('#confirmModal h3');
          if(titleEl && message){ titleEl.textContent = message; }
          var confirmBtn = document.getElementById('confirmModalConfirm');
          if(confirmBtn){ confirmBtn.textContent = confirmLabel; }
          openModal(url);
        }
      }
    }, true);

    if(cancelBtn){ cancelBtn.addEventListener('click', closeModal); }
    if(confirmBtn){ confirmBtn.addEventListener('click', function(){ if(form){ form.submit(); } closeModal(); }); }
    if(modal){ modal.addEventListener('click', function(e){ if(e.target === modal){ closeModal(); } }); }
  });
})();


