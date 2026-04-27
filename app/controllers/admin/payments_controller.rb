class Admin::PaymentsController < Admin::BaseController
  include Admin::PaymentPostingConcern
  before_action :set_payment, only: [ :edit, :update ]

  def index
    payments = Payment.includes(
      :organization, :payer, :processed_by_user,
      payment_applications: { encounter: :patient }
    )
    .order(created_at: :desc)
    payments = apply_filters(payments)
    @pagy, @payments = pagy(payments, items: 20)
    prepare_filter_ui_options
  end

  def new
    unless params[:encounter_id].present?
      redirect_to admin_encounters_path, alert: "Select an encounter to post payments."
      return
    end

    @payment = Payment.new
    build_payment_context

    # When loading inside a Turbo Frame modal, return only the form partial.
    if turbo_frame_request?
      render partial: "modal_form_frame",
             locals: {
               payment: @payment,
               encounter: @encounter,
               claim_lines: @claim_lines,
               applications_by_line: @applications_by_line,
               billed_amounts_by_line_id: @billed_amounts_by_line_id
             },
             layout: false
      return
    end
  end

  def edit
    @encounter = @payment.primary_encounter
    unless @payment.service_line_editable? && @encounter.present?
      redirect_to admin_payments_path, alert: "This payment cannot be edited through service-line posting."
      return
    end

    build_payment_context
  end

  def create
    unless params[:encounter_id].present?
      redirect_to admin_encounters_path, alert: "Select an encounter to post payments."
      return
    end

    build_payment_context
    create_manual_payment_from_params

    notice_message = @encounter ? "Payments posted for encounter." : "Payment created."

    if turbo_frame_request?
      flash.now[:notice] = notice_message
      streams = [
        turbo_stream.replace(
          "manualPaymentModal",
          partial: "admin/payments/manual_payment_modal_hidden"
        ),
        turbo_stream.replace(
          "manual-payment-modal-frame",
          partial: "admin/payments/modal_form_frame_empty"
        ),
        turbo_stream.update(
          "flash_container",
          partial: "shared/toast_flash"
        )
      ]

      if @encounter.present?
        @encounter.reload
        streams << turbo_stream.replace(
          "encounter-row-#{@encounter.id}",
          partial: "admin/encounters/encounter_row",
          locals: {
            encounter: @encounter,
            can_open_manual_payment_modal: current_user&.permissions_for("admin", "payments", "create")
          }
        )
      end

      render turbo_stream: streams
    else
      if @encounter
        redirect_to admin_encounter_path(@encounter), notice: notice_message
      else
        redirect_to admin_payments_path, notice: notice_message
      end
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    @payment ||= Payment.new
    if e.respond_to?(:record) && e.record.respond_to?(:errors) && e.record.errors.any?
      detail = e.record.errors.full_messages.join(", ")
      @payment.errors.add(:base, detail) if @payment.errors.empty?
      flash.now[:alert] = "Failed to save payment: #{detail}"
    else
      @payment.errors.add(:base, e.message) if @payment.errors.empty?
      flash.now[:alert] = "Failed to save payment: #{e.message}"
    end

    if turbo_frame_request?
      render partial: "modal_form_frame",
             locals: {
               payment: @payment,
               encounter: @encounter,
               claim_lines: @claim_lines,
               applications_by_line: @applications_by_line,
               billed_amounts_by_line_id: @billed_amounts_by_line_id
             },
             status: :unprocessable_entity,
             layout: false
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @encounter = @payment.primary_encounter
    unless @payment.service_line_editable? && @encounter.present?
      redirect_to admin_payments_path, alert: "This payment cannot be edited through service-line posting."
      return
    end

    build_payment_context
    update_manual_payment_from_params

    redirect_to admin_encounter_path(@encounter), notice: "Payment updated."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    if e.respond_to?(:record) && e.record.respond_to?(:errors) && e.record.errors.any?
      detail = e.record.errors.full_messages.join(", ")
      @payment.errors.add(:base, detail) if @payment.errors.empty?
      flash.now[:alert] = "Failed to update payment: #{detail}"
    else
      @payment.errors.add(:base, e.message) if @payment.errors.empty?
      flash.now[:alert] = "Failed to update payment: #{e.message}"
    end

    render :edit, status: :unprocessable_entity
  end

  private

  def set_payment
    @payment = Payment.includes(payment_applications: [ :encounter, { claim_line: :procedure_code } ]).find(params[:id])
  end

  def base_payments_scope
  end
end
