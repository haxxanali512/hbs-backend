/**
 * When the prepare_encounter_frame is replaced (e.g. after a validation error),
 * reset the workflow form's one-time init flags so the inline script in the
 * partial runs again and dropdowns/search work on the new form.
 * Set workflowFormFrameJustReplaced so the partial only runs its immediate
 * init when the frame was just replaced (not on first load, when other scripts
 * in the partial haven't run yet).
 */
function resetWorkflowFormInitFlags() {
  window.workflowDiagnosisInitialized = false;
  window.workflowProcedureInitialized = false;
  window.workflowPrescriptionInitialized = false;
  window.encounterTemplatesInitialized = false;
  window.workflowFormFrameJustReplaced = true;
}

document.addEventListener(
  "turbo:before-stream-render",
  (event) => {
    const stream = event.target;
    if (!stream || typeof stream.getAttribute !== "function") return;
    const target = stream.getAttribute("target");
    if (target === "prepare_encounter_frame") {
      resetWorkflowFormInitFlags();
    }
  },
  true
);
