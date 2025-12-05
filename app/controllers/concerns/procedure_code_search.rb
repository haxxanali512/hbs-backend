module ProcedureCodeSearch
  extend ActiveSupport::Concern

  # Search procedure codes and fetch pricing for billing forms
  def procedure_codes_search
    search_term = params[:q] || params[:search] || ""
    procedure_code_id = params[:procedure_code_id]
    line_id = params[:line_id] || "default"

    if procedure_code_id.present?
      handle_procedure_code_pricing(procedure_code_id, line_id)
    else
      handle_procedure_code_search(search_term, line_id)
    end
  rescue => e
    Rails.logger.error("Error in procedure_codes_search: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    handle_search_error(e, line_id)
  end

  private

  def handle_procedure_code_pricing(procedure_code_id, line_id)
    procedure_code = ProcedureCode.find_by(id: procedure_code_id)

    unless procedure_code
      render json: { success: false, error: "Procedure code not found" }, status: :not_found
      return
    end

    pricing_result = FeeSchedulePricingService.resolve_pricing(
      current_organization_for_pricing.id,
      current_encounter_for_pricing.provider_id,
      procedure_code.id
    )

    # Fallback: if service doesn't find pricing, use .last item from procedure code
    if !pricing_result[:success] && procedure_code.organization_fee_schedule_items.any?
      # Try to find an active item first, then fall back to any item
      fallback_item = procedure_code.organization_fee_schedule_items
                                    .where(active: true)
                                    .last ||
                     procedure_code.organization_fee_schedule_items.last

      if fallback_item
        pricing_result = {
          success: true,
          pricing: fallback_item.pricing_snapshot,
          source: "fallback_last_item",
          schedule_id: fallback_item.organization_fee_schedule_id,
          item_id: fallback_item.id
        }
        Rails.logger.warn("Using fallback pricing from last item for procedure_code_id: #{procedure_code_id}, item_id: #{fallback_item.id}, active: #{fallback_item.active?}")
      end
    end

    respond_to do |format|
      format.json do
        render_procedure_code_pricing_json(procedure_code, pricing_result)
      end
      format.turbo_stream do
        render_procedure_code_pricing_turbo_stream(procedure_code, pricing_result, line_id)
      end
    end
  end

  def handle_procedure_code_search(search_term, line_id)
    procedure_codes = ProcedureCode.kept.active
                                   .search(search_term)
                                   .limit(50)
                                   .order(:code)

    respond_to do |format|
          format.json do
            render json: {
              success: true,
              results: procedure_codes.map do |pc|
                {
                  id: pc.id,
                  code: pc.code || "",
                  description: pc.description || "",
                  code_type: pc.code_type || nil,
                  display: "#{pc.code || 'N/A'} - #{pc.description || 'No description'}"
                }
              end
            }
          end
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "procedure_code_#{line_id}_results",
          partial: "shared/procedure_code_results",
          locals: {
            line_id: line_id,
            procedure_codes: procedure_codes,
            search_url: procedure_codes_search_path_for_encounter
          }
        )
      end
    end
  end

  def render_procedure_code_pricing_json(procedure_code, pricing_result)
    if pricing_result[:success]
      render json: {
        success: true,
        procedure_code: {
          id: procedure_code.id,
          code: procedure_code.code,
          description: procedure_code.description,
          code_type: procedure_code.code_type
        },
        unit_price: pricing_result[:pricing][:unit_price].to_f,
        pricing_rule: pricing_result[:pricing][:pricing_rule],
        source: pricing_result[:source]
      }
    else
      render json: {
        success: false,
        error: pricing_result[:error],
        procedure_code: {
          id: procedure_code.id,
          code: procedure_code.code,
          description: procedure_code.description
        }
      }
    end
  end

  def render_procedure_code_pricing_turbo_stream(procedure_code, pricing_result, line_id)
    if pricing_result[:success]
      render turbo_stream: turbo_stream.update(
        "procedure_code_#{line_id}_unit_price",
        partial: "shared/procedure_code_unit_price",
        locals: {
          line_id: line_id,
          unit_price: pricing_result[:pricing][:unit_price].to_f,
          pricing_rule: pricing_result[:pricing][:pricing_rule],
          procedure_code: procedure_code
        }
      )
    else
      render turbo_stream: turbo_stream.update(
        "procedure_code_#{line_id}_unit_price",
        "<div class='p-3 text-sm text-red-500'>Error: #{pricing_result[:error]}</div>"
      )
    end
  end

  def handle_search_error(error, line_id)
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          error: error.message
        }, status: :unprocessable_entity
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "procedure_code_#{line_id}_results",
          "<div class='p-3 text-sm text-red-500'>Error: #{error.message}</div>"
        )
      end
    end
  end

  # Abstract methods that must be implemented by including controllers
  def current_organization_for_pricing
    raise NotImplementedError, "Must implement current_organization_for_pricing"
  end

  def current_encounter_for_pricing
    raise NotImplementedError, "Must implement current_encounter_for_pricing"
  end

  def procedure_codes_search_path_for_encounter
    raise NotImplementedError, "Must implement procedure_codes_search_path_for_encounter"
  end
end
