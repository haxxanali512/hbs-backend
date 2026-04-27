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
    @encounter ||= @payment.primary_encounter if @payment.persisted?

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
      if @payment.persisted?
        @payment.payment_applications.index_by(&:claim_line_id)
      elsif @encounter
        @encounter.payment_applications.index_by(&:claim_line_id)
      else
        {}
      end
    @payers = Payer.active_only.order(:name)
    @default_payer = @encounter&.patient_insurance_coverage&.insurance_plan&.payer
    @selected_payer = @payment&.payer || @default_payer
    @payment_adjustments = @payment&.payment_adjustments&.order(:created_at)&.to_a || []
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
    if params[:status].present?
      status_key = params[:status].to_s
      if Encounter.payment_statuses.key?(status_key)
        scope = scope.joins(payment_applications: :encounter).where(encounters: { payment_status: Encounter.payment_statuses[status_key] }).distinct
      elsif Payment.payment_statuses.key?(status_key)
        scope = scope.where(payment_status: status_key)
      end
    end
    scope = scope.where(payment_method: params[:payment_method]) if params[:payment_method].present?
    scope = scope.where(payer_id: params[:payer_id]) if params[:payer_id].present?

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
         .left_joins(payment_applications: { encounter: :patient })
         .where(
           "organizations.name ILIKE :term OR payers.name ILIKE :term OR patients.first_name ILIKE :term OR patients.last_name ILIKE :term OR CONCAT_WS(' ', patients.first_name, patients.last_name) ILIKE :term OR encounters.id::text ILIKE :term",
           term: term
         ).distinct
  end

  def prepare_filter_ui_options
    @search_placeholder = "Patient, encounter ID, payer, organization..."
    @organization_options = Organization.order(:name)
    @status_options = Encounter::PAYMENT_STATUS_FILTER_OPTIONS
    @payer_options = Payer.active_only.order(:name).map { |p| [ p.name, p.id ] }
    @custom_selects = []
    @show_date_range = true
  end

  def create_manual_payment_from_params
    persist_manual_payment!(payment: nil)
  end

  def update_manual_payment_from_params
    persist_manual_payment!(payment: @payment)
  end

  def persist_manual_payment!(payment:)
    raw_service_lines = params[:service_lines] || {}
    service_lines_params =
      if raw_service_lines.is_a?(ActionController::Parameters)
        raw_service_lines.permit!.to_h
      else
        raw_service_lines.to_h
      end
    payment_params =
      if params[:payment].is_a?(ActionController::Parameters)
        params[:payment].permit(:payment_date, :remit_reference, :payer_id, :generate_invoice, :notes)
      else
        ActionController::Parameters.new
      end
    raw_adjustments = params[:payment_adjustments] || {}
    payment_adjustments_params =
      if raw_adjustments.is_a?(ActionController::Parameters)
        raw_adjustments.permit!.to_h
      else
        raw_adjustments.to_h
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
        next 0.to_d unless PaymentApplication::PAYMENT_SIDE_LINE_STATUS_KEYS.include?(status)

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

      adjustment_attributes = normalize_adjustment_attributes(payment_adjustments_params)
      adjustments_total = adjustment_attributes.sum { |attrs| signed_adjustment_amount(attrs) }

      resolved_remit_reference = unique_manual_remit_reference(
        org_id: org_id,
        payer_id: payer&.id,
        encounter_id: @encounter&.id,
        preferred_reference: remit_reference,
        excluding_payment_id: payment&.id
      )

      final_amount_total = total_amount + adjustments_total
      if final_amount_total.negative?
        raise ActiveRecord::RecordInvalid.new(payment || Payment.new), "Adjustments would reduce the final net payment below zero."
      end

      @payment =
        if payment.present?
          payment.update!(
            organization_id: org_id,
            payer: payer,
            payment_date: payment_date || Date.current,
            amount: final_amount_total,
            amount_total: final_amount_total,
            remit_reference: resolved_remit_reference,
            payment_status: :succeeded,
            payment_method: :manual,
            notes: payment_params[:notes].presence
          )
          payment
        else
          Payment.create!(
            invoice_id: nil,
            amount: final_amount_total, # legacy invoice column is NOT NULL in production
            organization_id: org_id,
            payer: payer,
            payment_date: payment_date || Date.current,
            amount_total: final_amount_total,
            remit_reference: resolved_remit_reference,
            source_hash: SecureRandom.uuid,
            payment_status: :succeeded,
            payment_method: :manual,
            processed_by_user: current_user,
            notes: payment_params[:notes].presence
          )
        end

      if @encounter && @claim
        claim_lines = @claim.claim_lines.includes(:procedure_code).to_a
        claim_lines_by_id = claim_lines.index_by { |line| line.id.to_s }
        procedure_items_by_id = @encounter.encounter_procedure_items.index_by { |item| item.id.to_s }
        used_claim_line_ids = []
        processed_application_keys = []

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
            sync_payment_application!(
              payment: @payment,
              claim: @claim,
              claim_line: nil,
              encounter: @encounter,
              amount_applied: amount_value,
              line_status: line_status,
              denial_reason: denial_reason,
              note: note.presence || "Interest Payment"
            )
            processed_application_keys << "interest"
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

          sync_payment_application!(
            payment: @payment,
            claim: @claim,
            claim_line: claim_line,
            encounter: @encounter,
            amount_applied: amount_value,
            line_status: line_status,
            denial_reason: denial_reason,
            note: note
          )
          processed_application_keys << claim_line.id.to_s
        end

        cleanup_unused_payment_applications!(@payment, processed_application_keys)

        if @payment.payment_applications.reload.empty?
          if payment.present?
            raise ActiveRecord::RecordInvalid.new(@payment), "No valid service lines were mapped for this encounter payment."
          else
            @payment.destroy!
            raise ActiveRecord::RecordInvalid.new(@payment), "No valid service lines were mapped for this encounter payment."
          end
        end

        sync_payment_adjustments!(@payment, adjustment_attributes)

        @encounter.recalculate_payment_summary!
      elsif @encounter
        # Claim is an auxiliary artifact. Do not crash payment posting if it's absent.
        sync_payment_adjustments!(@payment, adjustment_attributes)
        update_encounter_payment_summary_without_claim!(
          final_amount_total,
          payment_date,
          previous_total: payment.present? ? payment.current_amount_total.to_d : 0.to_d
        )
      end
    end
  end

  def unique_manual_remit_reference(org_id:, payer_id:, encounter_id:, preferred_reference:, excluding_payment_id: nil)
    base_reference = preferred_reference.presence || (encounter_id ? "MANUAL-#{encounter_id}-#{Time.current.to_i}" : "MANUAL-#{Time.current.to_i}")
    existing_scope = Payment.where(organization_id: org_id, payer_id: payer_id, remit_reference: base_reference)
    existing_scope = existing_scope.where.not(id: excluding_payment_id) if excluding_payment_id.present?
    return base_reference unless existing_scope.exists?

    1.upto(999) do |index|
      candidate = "#{base_reference}-#{index}"
      scope = Payment.where(organization_id: org_id, payer_id: payer_id, remit_reference: candidate)
      scope = scope.where.not(id: excluding_payment_id) if excluding_payment_id.present?
      return candidate unless scope.exists?
    end

    "#{base_reference}-#{SecureRandom.hex(3)}"
  end

  def should_create_claim_for_payment_posting?
    return false unless @encounter.present?

    @encounter.encounter_procedure_items.joins(:procedure_code).exists?
  end

  def normalize_adjustment_attributes(raw_adjustments)
    raw_adjustments.values.filter_map do |attrs|
      next unless attrs.is_a?(Hash)
      next if ActiveModel::Type::Boolean.new.cast(attrs["_destroy"])

      amount_raw = attrs[:amount].to_s.presence || attrs["amount"].to_s.presence
      reason = attrs[:reason].to_s.presence || attrs["reason"].to_s.presence
      notes = attrs[:notes].to_s.presence || attrs["notes"].to_s.presence
      adjustment_type = attrs[:adjustment_type].to_s.presence || attrs["adjustment_type"].to_s.presence
      adjustment_date = attrs[:adjustment_date].to_s.presence || attrs["adjustment_date"].to_s.presence
      next if amount_raw.blank? && reason.blank? && notes.blank? && adjustment_type.blank? && adjustment_date.blank?

      {
        id: attrs[:id].presence || attrs["id"].presence,
        adjustment_type: adjustment_type,
        amount: amount_raw.present? ? BigDecimal(amount_raw) : 0.to_d,
        adjustment_date: parse_adjustment_date(adjustment_date),
        reason: reason,
        notes: notes
      }
    end
  end

  def signed_adjustment_amount(attrs)
    amount = attrs[:amount].to_d
    attrs[:adjustment_type].to_s == "decrease" ? -amount : amount
  end

  def sync_payment_adjustments!(payment, adjustment_attributes)
    existing_adjustments = payment.payment_adjustments.index_by { |adjustment| adjustment.id.to_s }
    retained_ids = []

    adjustment_attributes.each do |attrs|
      adjustment =
        if attrs[:id].present? && existing_adjustments.key?(attrs[:id].to_s)
          retained_ids << attrs[:id].to_s
          existing_adjustments[attrs[:id].to_s]
        else
          payment.payment_adjustments.build
        end

      adjustment.assign_attributes(
        adjustment_type: attrs[:adjustment_type],
        amount: attrs[:amount],
        adjustment_date: attrs[:adjustment_date] || payment.payment_date || Date.current,
        reason: attrs[:reason],
        notes: attrs[:notes]
      )
      adjustment.save!
      retained_ids << adjustment.id.to_s
    end

    payment.payment_adjustments.where.not(id: retained_ids).destroy_all
  end

  def sync_payment_application!(payment:, claim:, claim_line:, encounter:, amount_applied:, line_status:, denial_reason:, note:)
    application =
      payment.payment_applications.find_or_initialize_by(
        claim_line: claim_line
      )

    application.claim = claim
    application.encounter = encounter
    application.patient = encounter.patient
    application.amount_applied = amount_applied
    application.line_status = line_status
    application.denial_reason = line_status.to_s == "denied" ? denial_reason : nil
    application.note = note
    application.save!
  end

  def cleanup_unused_payment_applications!(payment, processed_application_keys)
    payment.payment_applications.find_each do |application|
      key = application.claim_line_id.present? ? application.claim_line_id.to_s : "interest"
      application.destroy unless processed_application_keys.include?(key)
    end
  end

  def parse_adjustment_date(value)
    return nil if value.blank?

    Date.parse(value)
  rescue ArgumentError
    nil
  end

  def update_encounter_payment_summary_without_claim!(total_amount, payment_date, previous_total: 0.to_d)
    current_total = @encounter.total_paid_amount.to_d
    new_total = current_total - previous_total.to_d + total_amount.to_d
    new_total = 0.to_d if new_total.negative?
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
