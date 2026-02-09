/**
 * Encounter workflow: "Send for Billing" button and queued table checkboxes.
 * Uses document-level delegation and runs on turbo:load / turbo:after-stream-render
 * so it works when navigating via Turbo and when the queued table is updated by turbo stream.
 */

let workflowQueuedDelegationBound = false;

function getTableBody() {
  const byAttr = document.querySelector('[data-workflow-queued-target="tableBody"]');
  if (byAttr) return byAttr;
  const frame = document.getElementById('queued_encounters_frame');
  if (frame) {
    const tbody = frame.querySelector('tbody');
    if (tbody) return tbody;
  }
  return null;
}

function updateSubmitState() {
  const tableBody = getTableBody();
  const submitButton = document.getElementById('submit_queued_button');
  const encounterIdsInput = document.getElementById('encounter_ids_input');

  if (!tableBody) {
    if (submitButton) submitButton.disabled = true;
    return;
  }

  const checkedBoxes = tableBody.querySelectorAll('input.queued-encounter-checkbox:checked');
  const hasSelections = checkedBoxes.length > 0;

  if (submitButton) {
    submitButton.disabled = !hasSelections;
  }

  if (encounterIdsInput) {
    encounterIdsInput.value = Array.from(checkedBoxes).map((cb) => cb.value).join(',');
  }

  const selectAll = document.getElementById('select_all_queued');
  if (selectAll && tableBody) {
    const allCheckboxes = tableBody.querySelectorAll('input.queued-encounter-checkbox');
    const checked = tableBody.querySelectorAll('input.queued-encounter-checkbox:checked');
    selectAll.checked = allCheckboxes.length > 0 && checked.length === allCheckboxes.length;
    selectAll.indeterminate = checked.length > 0 && checked.length < allCheckboxes.length;
  }
}

function collectSelectedIds() {
  const tableBody = getTableBody();
  if (!tableBody) return [];
  const checkedBoxes = tableBody.querySelectorAll('input.queued-encounter-checkbox:checked');
  return Array.from(checkedBoxes).map((cb) => cb.value);
}

function toggleAll(event) {
  const tableBody = getTableBody();
  if (!tableBody) return;
  const checkboxes = tableBody.querySelectorAll('input.queued-encounter-checkbox');
  const isChecked = event.target.checked;
  checkboxes.forEach((checkbox) => {
    checkbox.checked = isChecked;
  });
  updateSubmitState();
}

function bindDelegation() {
  if (workflowQueuedDelegationBound) return;
  workflowQueuedDelegationBound = true;

  document.addEventListener('change', (event) => {
    const el = event.target;
    if (!el || el.type !== 'checkbox') return;
    if (el.id === 'select_all_queued') {
      toggleAll(event);
    } else {
      const tableBody = getTableBody();
      if (tableBody && tableBody.contains(el)) {
        updateSubmitState();
      }
    }
  });
}

function bindSubmitForm() {
  const form = document.getElementById('submit-queued-form');
  if (!form || form.dataset.workflowQueuedBound === 'true') return;
  form.dataset.workflowQueuedBound = 'true';

  form.addEventListener('submit', (event) => {
    const encounterIdsInput = document.getElementById('encounter_ids_input');
    const selectedIds = collectSelectedIds();
    if (encounterIdsInput) {
      encounterIdsInput.value = selectedIds.join(',');
    }
    if (selectedIds.length === 0) {
      event.preventDefault();
    }
  });
}

function initWorkflowQueued() {
  if (!document.getElementById('submit-queued-form')) return;

  bindDelegation();
  bindSubmitForm();
  updateSubmitState();
}

// Row click: navigate to edit (used by onclick in queued_table partial)
function handleRowClick(event, encounterId) {
  if (
    event.target.tagName === 'INPUT' ||
    event.target.tagName === 'A' ||
    event.target.tagName === 'BUTTON' ||
    event.target.closest('a') ||
    event.target.closest('button')
  ) {
    return;
  }
  const base = window.location.pathname.replace(/\/workflow\/?$/, '') || '/tenant/encounters';
  window.location.href = `${base}/${encounterId}/edit`;
}

// Expose for onclick in _queued_table.html.erb and for inline script on workflow page
window.handleRowClick = handleRowClick;
window.initWorkflowQueued = initWorkflowQueued;

document.addEventListener('turbo:load', initWorkflowQueued);
document.addEventListener('DOMContentLoaded', initWorkflowQueued);
document.addEventListener('turbo:after-stream-render', () => {
  initWorkflowQueued();
  setTimeout(initWorkflowQueued, 100);
});
document.addEventListener('turbo:frame-load', (event) => {
  if (event.target.id === 'queued_encounters_frame') {
    initWorkflowQueued();
    setTimeout(initWorkflowQueued, 100);
  }
});
