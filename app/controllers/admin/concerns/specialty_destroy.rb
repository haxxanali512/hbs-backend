module Admin::Concerns::SpecialtyDestroy
  extend ActiveSupport::Concern

  private

  def cascade_delete_specialty!(specialty)
    Specialty.transaction do
      encounter_ids = Encounter.where(specialty_id: specialty.id).pluck(:id)
      cascade_delete_encounters!(encounter_ids) if encounter_ids.any?

      cascade_delete_claims!(Claim.where(specialty_id: specialty.id).pluck(:id))

      appt_ids = Appointment.where(specialty_id: specialty.id).pluck(:id)
      if appt_ids.any?
        Encounter.where(appointment_id: appt_ids).update_all(appointment_id: nil)
        Appointment.where(id: appt_ids).delete_all
      end

      prescription_ids = Prescription.where(specialty_id: specialty.id).pluck(:id)
      if prescription_ids.any?
        PrescriptionDiagnosisCode.where(prescription_id: prescription_ids).delete_all
        ActiveStorage::Attachment.where(record_type: "Prescription", record_id: prescription_ids).delete_all
        Prescription.where(id: prescription_ids).delete_all
      end

      template_ids = EncounterTemplate.where(specialty_id: specialty.id).pluck(:id)
      if template_ids.any?
        Encounter.where(encounter_template_id: template_ids).update_all(encounter_template_id: nil)
        EncounterTemplateLine.where(encounter_template_id: template_ids).delete_all
        EncounterTemplate.where(id: template_ids).delete_all
      end

      specialty.procedure_codes_specialties.delete_all
      specialty.provider_specialties.delete_all
      specialty.organization_fee_schedule_specialties.delete_all
      specialty.destroy!
    end
  end

  def cascade_delete_encounters!(encounter_ids)
    return if encounter_ids.empty?

    comment_ids = EncounterComment.where(encounter_id: encounter_ids).pluck(:id)
    if comment_ids.any?
      EncounterCommentAttachment.where(encounter_comment_id: comment_ids).each do |att|
        att.file.purge if att.file.attached?
      end
      EncounterCommentAttachment.where(encounter_comment_id: comment_ids).delete_all
      EncounterComment.where(id: comment_ids).delete_all
    end

    EncounterCommentSeen.where(encounter_id: encounter_ids).delete_all
    ClinicalDocumentation.where(encounter_id: encounter_ids).delete_all
    EncounterDiagnosisCode.where(encounter_id: encounter_ids).delete_all
    EncounterProcedureItem.where(encounter_id: encounter_ids).delete_all
    ProviderNote.where(encounter_id: encounter_ids).delete_all

    cascade_delete_claims!(Claim.where(encounter_id: encounter_ids).pluck(:id))

    ActiveStorage::Attachment.where(record_type: "Encounter", record_id: encounter_ids).delete_all
    Encounter.where(id: encounter_ids).delete_all
  end

  def cascade_delete_claims!(claim_ids)
    return if claim_ids.empty?

    denial_ids = Denial.where(claim_id: claim_ids).pluck(:id)
    if denial_ids.any?
      DenialItem.where(denial_id: denial_ids).delete_all
      ActiveStorage::Attachment.where(record_type: "Denial", record_id: denial_ids).delete_all
      Denial.where(id: denial_ids).delete_all
    end

    pa_ids = ActiveRecord::Base.connection.select_values(
      "SELECT id FROM payment_applications WHERE claim_id IN (#{claim_ids.join(',')})"
    )
    if pa_ids.any?
      ActiveStorage::Attachment.where(record_type: "PaymentApplication", record_id: pa_ids).delete_all
      ActiveRecord::Base.connection.execute(
        "DELETE FROM payment_applications WHERE id IN (#{pa_ids.join(',')})"
      )
    end

    ClaimSubmission.where(claim_id: claim_ids).delete_all
    ClaimLine.where(claim_id: claim_ids).delete_all
    ActiveStorage::Attachment.where(record_type: "Claim", record_id: claim_ids).delete_all
    Claim.where(id: claim_ids).delete_all
  end
end
