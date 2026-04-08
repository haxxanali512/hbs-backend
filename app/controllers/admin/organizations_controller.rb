class Admin::OrganizationsController < Admin::BaseController
  include Admin::Concerns::OrganizationConcern
  include ActivationStepsConcern

  before_action :set_organization, only: [ :show, :edit, :update, :destroy, :hard_destroy, :activate_tenant, :suspend_tenant, :charge_monthly_invoice, :preview_monthly_invoice, :toggle_checklist_step, :toggle_plan_step ]

  def index
    @organizations = build_organizations_index_query.with_discarded
    @organizations = apply_organizations_search(@organizations)
    @organizations = apply_organizations_status_filter(@organizations)
    case params[:archived]
    when "archived"
      @organizations = @organizations.discarded
    when "all"
      # keep all
    else
      @organizations = @organizations.kept
    end
    @pagy, @organizations = pagy(@organizations, items: 20)
  end

  def show
    @onboarding_steps = build_detailed_activation_steps(@organization) if @organization.activated?
  end

  def preview_monthly_invoice
    period = billing_period_from_params
    calculation = ClaimsCalculator.calculate(@organization, period)
    total_cents = calculation[:line_items].sum { |item| item[:amount_cents].to_i }

    preview_payload = {
      period_start: period.begin.to_date,
      period_end: period.end.to_date,
      service_month: period.begin.strftime("%Y-%m"),
      collection_rate_percent: calculation[:collection_rate_percent],
      collections_cents: calculation[:collections_cents],
      deductible_claims_count: calculation[:deductible_claims_count],
      line_items: calculation[:line_items],
      total_cents: total_cents
    }

    respond_to do |format|
      format.json { render json: { success: true, preview: preview_payload } }
      format.html { redirect_to admin_organization_path(@organization), notice: "Billing preview is available in the preview modal." }
    end
  rescue => e
    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to admin_organization_path(@organization), alert: "Could not generate billing preview: #{e.message}" }
    end
  end

  def new
    @organization = Organization.new
    build_organization_associations
  end

  def create
    if create_organization_with_associations
      redirect_to admin_organization_path(@organization), notice: organization_created_message
    else
      flash.now[:alert] = organization_creation_error_message
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_organization_associations
  end

  def update
    if update_organization_with_associations
      redirect_to admin_organization_path(@organization), notice: "Organization was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    organization_name = @organization.name
    owner_email = @organization.owner.email

    @organization.discard
    NotificationService.notify_organization_deleted(organization_name, owner_email)

    redirect_to admin_organizations_path, notice: "Organization was successfully deleted."
  end

  def hard_destroy
    unless current_user&.permissions_for("admin", "organizations", "hard_destroy")
      redirect_to admin_organizations_path, alert: "You do not have permission to permanently delete organizations."
      return
    end

    Organization.transaction do
      # Best-effort deep destroy; some associations use restrict_with_error and may block deletion
      @organization.support_tickets.destroy_all
      @organization.notifications.destroy_all
      @organization.organization_memberships.destroy_all
      @organization.organization_locations.destroy_all
      @organization.organization_fee_schedules.destroy_all
      @organization.patients.destroy_all
      @organization.invoices.destroy_all
      @organization.payments.destroy_all

      @organization.destroy!
    end

    redirect_to admin_organizations_path, notice: "Organization and related data permanently deleted."
  rescue => e
    redirect_to admin_organization_path(@organization), alert: "Could not permanently delete organization: #{e.message}"
  end

  def activate_tenant
    result = OrganizationDirectActivationService.new(
      organization: @organization,
      activated_by: current_user
    ).call

    if result[:success]
      if params[:invite_owner].present? && @organization.owner.present?
        send_owner_activation_invite
      end
      notice = "Organization activated successfully (bypassed activation workflow)."
      notice += " An invite email has been sent to the owner." if params[:invite_owner].present? && @organization.owner.present?
      redirect_to admin_organization_path(@organization), notice: notice
    else
      redirect_to admin_organization_path(@organization),
                  alert: "Cannot activate organization: #{result[:errors].join(', ')}"
    end
  end

  def suspend_tenant
    @organization.update(activation_status: :pending)
    NotificationService.notify_organization_suspended(@organization)

    redirect_to admin_organization_path(@organization),
                notice: "Organization suspended successfully."
  end

  def charge_monthly_invoice
    billing = @organization.organization_billing
    unless billing&.active?
      redirect_to admin_organization_path(@organization), alert: "Billing is not configured or not active for this organization."
      return
    end

    month = params[:month].presence
    period = if month.present?
      begin
        parsed = Date.strptime(month, "%Y-%m")
        parsed.beginning_of_month..parsed.end_of_month
      rescue ArgumentError
        nil
      end
    else
      previous_month = Time.current.beginning_of_month - 1.day
      previous_month.beginning_of_month.to_date..previous_month.end_of_month.to_date
    end

    unless period
      redirect_to admin_organization_path(@organization), alert: "Invalid month format. Use YYYY-MM."
      return
    end

    OrganizationMonthlyBillingJob.perform_later(
      @organization.id,
      period_start: period.begin,
      period_end: period.end
    )

    redirect_to admin_organization_path(@organization), notice: "Monthly billing was queued for #{period.begin.strftime('%B %Y')}."
  end

  def toggle_checklist_step
    checklist = @organization.activation_checklist || @organization.create_activation_checklist
    step = params[:step]

    case step
    when "waystar_child_account"
      checklist.update!(waystar_child_account_completed: !checklist.waystar_child_account_completed?)
      send_checklist_step_notification(checklist, "Waystar Child Account", checklist.waystar_child_account_completed?)
    when "ezclaim_record"
      checklist.update!(ezclaim_record_completed: !checklist.ezclaim_record_completed?)
      send_checklist_step_notification(checklist, "EZClaim Record", checklist.ezclaim_record_completed?)
    when "initial_encounter_billed"
      checklist.update!(initial_encounter_billed_completed: !checklist.initial_encounter_billed_completed?)
      send_checklist_step_notification(checklist, "Initial Encounter Billed", checklist.initial_encounter_billed_completed?)
    when "name_match"
      checklist.update!(name_match_completed: !checklist.name_match_completed?)
      send_checklist_step_notification(checklist, "Name Match", checklist.name_match_completed?)
    else
      redirect_to admin_organization_path(@organization), alert: "Invalid step."
      return
    end

    redirect_to admin_organization_path(@organization), notice: "Checklist step updated successfully."
  end

  def toggle_plan_step
    plan = @organization.org_accepted_plans.find(params[:plan_id])
    step_type = params[:step_type]

    step = OrganizationActivationPlanStep.find_or_initialize_by(
      org_accepted_plan_id: plan.id,
      step_type: step_type
    )

    if step.persisted?
      if step.completed?
        step.mark_pending!
      else
        step.mark_completed!(current_user)
      end
    else
      step.save!
      step.mark_completed!(current_user)
    end

    send_plan_step_notification(plan, step_type, step.completed?)

    redirect_to admin_organization_path(@organization), notice: "Plan step updated successfully."
  end

  def users_search
    search_term = params[:q] || params[:search] || ""

    users = User.kept
                .where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ? OR username ILIKE ?",
                       "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
                .order(:first_name, :last_name)
                .limit(50)

    render json: {
      success: true,
      results: users.map do |user|
        {
          id: user.id,
          name: user.display_name,
          email: user.email,
          display: "#{user.display_name} (#{user.email})"
        }
      end
    }
  rescue => e
    Rails.logger.error("Error in users_search: #{e.message}")
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(
      :name,
      :subdomain,
      :tier,
      :owner_id,
      organization_setting_attributes: [
        :id,
        :ezclaim_enabled,
        :ezclaim_api_token,
        :ezclaim_api_url,
        :ezclaim_api_version,
        feature_entitlements: {}
      ],
      organization_contact_attributes: [
        :id,
        :address_line1,
        :address_line2,
        :city,
        :state,
        :zip,
        :country,
        :phone,
        :email,
        :time_zone,
        :contact_type
      ],
      organization_identifier_attributes: [
        :id,
        :tax_identification_number,
        :tax_id_type,
        :npi,
        :npi_type,
        :identifiers_change_status,
        :identifiers_change_docs,
        :previous_tin,
        :previous_npi,
        :identifiers_change_effective_on
      ]
    )
  end

  def billing_period_from_params
    month = params[:month].presence
    return default_previous_month_period if month.blank?

    parsed = Date.strptime(month, "%Y-%m")
    parsed.beginning_of_month..parsed.end_of_month
  rescue ArgumentError
    default_previous_month_period
  end

  def default_previous_month_period
    previous_month = Time.current.beginning_of_month - 1.day
    previous_month.beginning_of_month.to_date..previous_month.end_of_month.to_date
  end

  def send_checklist_step_notification(checklist, step_name, completed)
    if completed
      OrganizationMailer.checklist_step_completed(@organization, step_name).deliver_now
    end
  end

  def send_plan_step_notification(plan, step_type, completed)
    if completed
      OrganizationMailer.plan_step_completed(@organization, plan, step_type).deliver_now
    end
  end

  def send_owner_activation_invite
    owner = @organization.owner
    return if owner.nil?

    # Generate an invitation token for the owner WITHOUT sending Devise's default
    # invitation email. We send a custom onboarding email via OrganizationMailer (direct mail).
    # This matches what Devise Invitable does internally but skips the mailer.
    raw_token, enc_token = Devise.token_generator.generate(User, :invitation_token)

    owner.invitation_token = enc_token
    owner.invitation_created_at = Time.current
    owner.invitation_sent_at = Time.current
    owner.invited_by = current_user
    owner.save!(validate: false)

    # Reload to ensure we have the latest state
    owner.reload
    mail = OrganizationMailer.owner_activation_invite(@organization, raw_token)
    mail.deliver_now
  rescue => e
    Rails.logger.error "[Admin::OrganizationsController] Failed to send owner activation invite: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    flash[:alert] = "Organization activated, but the owner invite email could not be sent: #{e.message}"
  end
end
