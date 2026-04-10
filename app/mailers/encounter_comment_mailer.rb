class EncounterCommentMailer < ApplicationMailer
  def encounter_comment_added
    @recipient = params[:recipient]
    @comment = params[:comment]
    @encounter = @comment.encounter
    @organization = @comment.organization
    @author = @comment.author
    @portal_url = params[:portal_url]

    patient_mrn = @comment.patient&.respond_to?(:mrn) ? @comment.patient&.mrn : nil
    @patient_identifier = if patient_mrn.present?
      patient_mrn
    else
      "Patient ##{@comment.patient_id}"
    end
    @date_of_service = @encounter&.date_of_service&.strftime("%m/%d/%Y") || "N/A"

    subject = "Encounter Comment Update — #{@organization&.name || 'Organization'}"
    mail(to: @recipient.email, subject: subject) do |format|
      format.html
      format.text
    end
  end
end
