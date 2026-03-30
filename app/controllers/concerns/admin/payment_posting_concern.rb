module Admin::PaymentPostingConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_encounter_context, only: [ :new, :create ]
  end

  private

  def set_encounter_context
    return unless params[:encounter_id].present?

    @encounter = Encounter.kept.find_by(id: params[:encounter_id])
  end

  def build_payment_context
    @payment = Payment.new if @payment.nil?

    if should_create_claim_for_payment_posting? && @encounter.claim.blank?
      @encounter.create_claim_with_lines_if_missing!
      @encounter.reload
    end

    @claim = @encounter&.claim
    claim_lines =
      if @claim&.claim_lines&.any?
        @claim.claim_lines.includes(:procedure_code)
      elsif @encounter
        # Keep service lines visible even before claim artifacts exist.
        @encounter.encounter_procedure_items.includes(:procedure_code)
      else
        []
      end
    @claim_lines = claim_lines
    @billed_amounts_by_line_id = {}
    if @encounter
      claim_lines.each do |line|
        @billed_amounts_by_line_id[line.id] = resolved_billed_amount_for_line(line)
      end
    end
    @applications_by_line =
      if @encounter
        @encounter.payment_applications.index_by(&:claim_line_id)
      else
        {}
      end
    @payers = Payer.active_only.order(:name)
    @default_payer = @encounter&.patient_insurance_coverage&.insurance_plan&.payer
    @selected_payer = @payment&.payer || @default_payer
  end

  def resolved_billed_amount_for_line(line)
    stored_amount = line.respond_to?(:amount_billed) ? line.amount_billed.to_d : 0.to_d
    return stored_amount if stored_amount.positive?

    return 0.to_d unless @encounter&.organization_id.present? && @encounter&.provider_id.present?

    procedure_code_id = line.respond_to?(:procedure_code_id) ? line.procedure_code_id : nil
    return 0.to_d if procedure_code_id.blank?

    units = line.respond_to?(:units) ? line.units.to_i : 1
    units = 1 unless units.positive?

    pricing_result = FeeSchedulePricingService.resolve_pricing(
      @encounter.organization_id,
      @encounter.provider_id,
      procedure_code_id
    )

    return 0.to_d unless pricing_result[:success]

    unit_price = pricing_result.dig(:pricing, :unit_price).to_d
    pricing_rule = pricing_result.dig(:pricing, :pricing_rule).to_s

    if pricing_rule == "flat"
      unit_price
    else
      unit_price * units
    end
  rescue => e
    Rails.logger.warn("Payment posting billed amount fallback failed for line #{line.id}: #{e.message}")
    0.to_d
  end

  def apply_filters(scope)
    scope = scope.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    scope = scope.where(payment_status: params[:status]) if params[:status].present?
    scope = scope.where(payment_method: params[:payment_method]) if params[:payment_method].present?

    scope = apply_date_filters(scope)
    scope = apply_search_filter(scope)

    scope
  end

  def apply_date_filters(scope)
    if params[:date_from].present?
      from = Date.parse(params[:date_from]) rescue nil
      if from
        scope = scope.where("payment_date >= ? OR (payment_date IS NULL AND created_at >= ?)", from, from)
      end
    end

    if params[:date_to].present?
      to = Date.parse(params[:date_to]) rescue nil
      if to
        scope = scope.where("payment_date <= ? OR (payment_date IS NULL AND created_at <= ?)", to, to)
      end
    end

    scope
  end

  def apply_search_filter(scope)
    return scope unless params[:search].present?

    term = "%#{params[:search]}%"
    scope.joins(:organization)
         .left_joins(:payer)
         .where(
           "payments.remit_reference ILIKE ? OR payments.source_hash ILIKE ? OR organizations.name ILIKE ? OR payers.name ILIKE ?",
           term, term, term, term
         )
  end

  def prepare_filter_ui_options
    @search_placeholder = "Remit reference, payer, org, source hash..."
    @organization_options = Organization.order(:name)
    @status_options = Payment.payment_statuses.keys
    @custom_selects = [
      {
        param: :payment_method,
        label: "Method",
        options: [ [ "All Methods", "" ] ] + Payment.payment_methods.keys.map { |m| [ m.humanize, m ] }
      }
    ]
    @show_date_range = true
  end

  def create_manual_payment_from_params
    raw_service_lines = params[:service_lines] || {}
    service_lines_params =
      if raw_service_lines.is_a?(ActionController::Parameters)
        raw_service_lines.permit!.to_h
      else
        raw_service_lines.to_h
      end
    payment_params =
      if params[:payment].is_a?(ActionController::Parameters)
        params[:payment].permit(:payment_date, :remit_reference, :payer_id, :generate_invoice)
      else
        ActionController::Parameters.new
      end

    payment_date = payment_params[:payment_date].presence && Date.parse(payment_params[:payment_date]) rescue nil
    remit_reference = payment_params[:remit_reference].presence

    ActiveRecord::Base.transaction do
      if should_create_claim_for_payment_posting? && @encounter.claim.blank?
        @encounter.create_claim_with_lines_if_missing!
        @encounter.reload
        @claim = @encounter.claim
      end
      @claim ||= @encounter&.claim

      total_amount = service_lines_params.values.sum do |attrs|
        next 0.to_d unless attrs.is_a?(Hash)

        status = attrs[:status].to_s.presence || attrs["status"].to_s
        next 0.to_d unless [ "paid", "adjusted" ].include?(status)

        amount_str = attrs[:amount_paid].to_s.presence || attrs["amount_paid"].to_s
        amount_str.present? ? BigDecimal(amount_str) : 0.to_d
      end

      org_id = @encounter&.organization_id || current_organization&.id || params[:organization_id]

      payer =
        if payment_params[:payer_id].present?
          Payer.find_by(id: payment_params[:payer_id])
        else
          @default_payer
        end

      resolved_remit_reference = unique_manual_remit_reference(
        org_id: org_id,
        payer_id: payer&.id,
        encounter_id: @encounter&.id,
        preferred_reference: remit_reference
      )

      @payment = Payment.create!(
        invoice_id: nil,
        amount: total_amount, # legacy invoice column is NOT NULL in production
        organization_id: org_id,
        payer: payer,
        payment_date: payment_date || Date.current,
        amount_total: total_amount,
        remit_reference: resolved_remit_reference,
        source_hash: SecureRandom.uuid,
        payment_status: :succeeded,
        payment_method: :manual,
        processed_by_user: current_user
      )

      if @encounter && @claim
        claim_lines = @claim.claim_lines.includes(:procedure_code).to_a
        claim_lines_by_id = claim_lines.index_by { |line| line.id.to_s }
        procedure_items_by_id = @encounter.encounter_procedure_items.index_by { |item| item.id.to_s }
        used_claim_line_ids = []
        created_applications_count = 0

        service_lines_params.each do |line_key, attrs|
          next unless attrs.is_a?(Hash)

          line_key_str = line_key.to_s

          amount = attrs[:amount_paid].to_s.presence || attrs["amount_paid"].to_s
          status = attrs[:status].to_s.presence || attrs["status"].to_s
          denial_reason = attrs[:denial_reason].to_s.presence || attrs["denial_reason"].to_s
          note = attrs[:note].to_s.presence || attrs["note"].to_s
          amount_value = amount.present? ? BigDecimal(amount) : 0.to_d
          next if amount_value.zero? && status.blank? && denial_reason.blank? && note.blank?

          line_status = status.presence || (amount_value.positive? ? "paid" : "unpaid")

          # Support a custom, non-CPT payment service line (e.g. interest payments).
          # These entries are persisted as PaymentApplications with `claim_line` unset.
          if line_key_str == "interest"
            PaymentApplication.create!(
              payment: @payment,
              claim: @claim,
              claim_line: nil,
              encounter: @encounter,
              patient: @encounter.patient,
              amount_applied: amount_value,
              line_status: line_status,
              denial_reason: line_status.to_s == "denied" ? denial_reason : nil,
              note: note.presence || "Interest Payment"
            )
            created_applications_count += 1
            next
          end

          claim_line = claim_lines_by_id[line_key.to_s]
          if claim_line.blank?
            # When UI line keys come from encounter_procedure_items, map to claim line by procedure code.
            procedure_item = procedure_items_by_id[line_key.to_s]
            if procedure_item.present?
              claim_line = claim_lines.find do |line|
                line.procedure_code_id == procedure_item.procedure_code_id && !used_claim_line_ids.include?(line.id)
              end
            end
          end

          if claim_line.blank?
            next
          end
          used_claim_line_ids << claim_line.id

          PaymentApplication.create!(
            payment: @payment,
            claim: @claim,
            claim_line: claim_line,
            encounter: @encounter,
            patient: @encounter.patient,
            amount_applied: amount_value,
            line_status: line_status,
            denial_reason: line_status.to_s == "denied" ? denial_reason : nil,
            note: note,
            # Note: keys are matched via claim_line_id; custom service lines
            # are handled by posting against actual claim lines.
          )
          created_applications_count += 1
        end

        if created_applications_count.zero?
          @payment.destroy!
          raise ActiveRecord::RecordInvalid.new(@payment), "No valid service lines were mapped for this encounter payment."
        end

        @encounter.recalculate_payment_summary!
      elsif @encounter
        # Claim is an auxiliary artifact. Do not crash payment posting if it's absent.
        update_encounter_payment_summary_without_claim!(total_amount, payment_date)
      end
    end
  end

  def unique_manual_remit_reference(org_id:, payer_id:, encounter_id:, preferred_reference:)
    base_reference = preferred_reference.presence || (encounter_id ? "MANUAL-#{encounter_id}-#{Time.current.to_i}" : "MANUAL-#{Time.current.to_i}")
    return base_reference unless Payment.exists?(organization_id: org_id, payer_id: payer_id, remit_reference: base_reference)

    1.upto(999) do |index|
      candidate = "#{base_reference}-#{index}"
      return candidate unless Payment.exists?(organization_id: org_id, payer_id: payer_id, remit_reference: candidate)
    end

    "#{base_reference}-#{SecureRandom.hex(3)}"
  end

  def should_create_claim_for_payment_posting?
    return false unless @encounter.present?

    @encounter.encounter_procedure_items.joins(:procedure_code).exists?
  end

  def update_encounter_payment_summary_without_claim!(total_amount, payment_date)
    current_total = @encounter.total_paid_amount.to_d
    new_total = current_total + total_amount.to_d
    status_key = new_total.positive? ? :partially_paid : :unpaid

    @encounter.update_columns(
      total_paid_amount: new_total,
      payment_status: Encounter.payment_statuses[status_key.to_s],
      payment_date: payment_date || Date.current,
      internal_status: Encounter.internal_statuses[:billed],
      tenant_status: Encounter.tenant_statuses[:in_process],
      shared_status: Encounter.shared_statuses[:finalized],
      updated_at: Time.current
    )
  end
end
