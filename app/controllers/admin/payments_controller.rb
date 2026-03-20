class Admin::PaymentsController < Admin::BaseController
  include Admin::PaymentPostingConcern

  def index
    payments = Payment.includes(:organization, :payer, :processed_by_user)
    .order(created_at: :desc)
    payments = apply_filters(payments)
    @pagy, @payments = pagy(payments, items: 20)
    prepare_filter_ui_options
  end

  def new
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

  def create
    build_payment_context
    create_manual_payment_from_params

    notice_message = @encounter ? "Payments posted for encounter." : "Payment created."

    if turbo_frame_request?
      flash.now[:notice] = notice_message
      render turbo_stream: [
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
    else
      if @encounter
        redirect_to admin_encounter_path(@encounter), notice: notice_message
      else
        redirect_to admin_payments_path, notice: notice_message
      end
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    flash.now[:alert] = "Failed to save payment: #{e.message}"

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

  private

  def base_payments_scope
  end
end
