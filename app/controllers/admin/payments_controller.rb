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
               applications_by_line: @applications_by_line
             },
             layout: false
      return
    end
  end

  def create
    build_payment_context
    create_manual_payment_from_params

    if @encounter
      redirect_to admin_encounter_path(@encounter), notice: "Payments posted for encounter."
    else
      redirect_to admin_payments_path, notice: "Payment created."
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    flash.now[:alert] = "Failed to save payment: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  private

  def base_payments_scope
  end
end
