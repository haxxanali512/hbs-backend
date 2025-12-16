class Tenant::DashboardController < Tenant::BaseController
  # before_action :check_activation_status, only: [ :activation, :billing_setup, :update_billing, :manual_payment, :compliance_setup, :update_compliance, :document_signing, :complete_document_signing, :activation_complete, :activate ]

  def index
    if @current_organization.activated?
      # For revenue-sharing tiers (6–9%), show practice metrics dashboard
      if @current_organization.tier_percentage&.in?([ 6.0, 7.0, 8.0, 9.0 ])
        build_tier_dashboard_metrics
      else
        # Default dashboard (can be refined later)
        @organizations_count = Organization.count
        @active_organizations = Organization.where(activation_status: :activated).count
        @total_users = User.count
        @pending_billings = OrganizationBilling.pending_approval.count
        @recent_organizations = Organization.order(created_at: :desc).limit(5)
        @recent_users = User.order(created_at: :desc).limit(5)

        # Calculate growth metrics
        @organizations_growth = calculate_growth(Organization, 30.days.ago)
        @users_growth = calculate_growth(User, 30.days.ago)
      end
    else
      # Redirect non-activated organizations to activation overview
      redirect_to tenant_activation_path
    end
  end

  # Activation methods (moved from Tenant::ActivationController)

  private

  def build_tier_dashboard_metrics
    org = @current_organization
    today = Date.current
    year_start = today.beginning_of_year

    # Patient & claim totals
    @total_patients = org.patients.count
    @active_patients = org.patients.active_patients.count

    claims = org.claims
    @total_claims = claims.count
    @claims_paid = claims.paid_in_full.count
    @claims_denied = claims.denied.count
    @claims_in_process = @total_claims - @claims_paid - @claims_denied

    # Revenue metrics (using remit-based payments if present, else legacy amount)
    payments = org.payments.where(payment_status: :succeeded)
    lifetime_total = payments.sum("COALESCE(amount_total, amount)")
    @total_paid_lifetime = lifetime_total
    @year_to_date_paid = payments.where("payment_date >= ? OR (payment_date IS NULL AND created_at >= ?)", year_start, year_start)
                                 .sum("COALESCE(amount_total, amount)")
    @last_30_days_paid = payments.where("payment_date >= ? OR (payment_date IS NULL AND created_at >= ?)", 30.days.ago.to_date, 30.days.ago)
                                 .sum("COALESCE(amount_total, amount)")
    @last_7_days_paid = payments.where("payment_date >= ? OR (payment_date IS NULL AND created_at >= ?)", 7.days.ago.to_date, 7.days.ago)
                                .sum("COALESCE(amount_total, amount)")

    total_billed = claims.sum(:total_billed) || 0
    @est_outstanding_ar = [ total_billed - lifetime_total, 0 ].max

    # Upcoming expirations
    @expiring_prescriptions_count =
      Prescription.active.joins(:patient)
                  .where(patients: { organization_id: org.id })
                  .where("expires_on BETWEEN ? AND ?", today, today + 30.days)
                  .count

    # Placeholders for visit caps and auth expirations until underlying models/fields exist
    @visit_caps_approaching_count = 0
    @auth_expirations_count = 0

    # ==============================
    # Advanced metrics (8% / 9% tiers)
    # ==============================
    # Only compute if organization is on higher tier
    return unless org.tier_percentage&.in?([ 8.0, 9.0 ])

    # Claim age summaries (outstanding claims only)
    outstanding_statuses = Claim.statuses.keys - %w[ paid_in_full denied voided reversed closed ]
    base_scope = claims.where(status: outstanding_statuses)

    @claim_age_0_30   = base_scope.where("created_at >= ?", 30.days.ago).count
    @claim_age_31_60  = base_scope.where("created_at >= ? AND created_at < ?", 60.days.ago, 30.days.ago).count
    @claim_age_61_90  = base_scope.where("created_at >= ? AND created_at < ?", 90.days.ago, 60.days.ago).count
    @claim_age_91_120 = base_scope.where("created_at >= ? AND created_at < ?", 120.days.ago, 90.days.ago).count
    @claim_age_120_plus = base_scope.where("created_at < ?", 120.days.ago).count

    # Averages & projections over last 90 days
    window_start = 90.days.ago.beginning_of_day
    payments_90 = payments.where("payment_date >= ? OR (payment_date IS NULL AND created_at >= ?)", window_start.to_date, window_start)
    payments_90_total = payments_90.sum("COALESCE(amount_total, amount)")

    encounters_90 = org.encounters.where("date_of_service >= ?", window_start.to_date)
    encounters_90_count = encounters_90.count
    providers_count = org.providers.active.count

    @avg_revenue_per_visit = encounters_90_count.positive? ? (payments_90_total / encounters_90_count.to_f) : 0.0
    @avg_revenue_per_provider = providers_count.positive? ? (payments_90_total / providers_count.to_f) : 0.0
    @avg_monthly_revenue = payments_90_total / 3.0
    @visits_per_month = encounters_90_count / 3.0

    # Simple projections based on last 90 days average
    @projected_30_day_revenue = @avg_monthly_revenue
    @projected_90_day_revenue = @avg_monthly_revenue * 3.0

    # Average days to payment (sample up to 200 allocations)
    begin
      sample_allocations = PaymentApplication.
        joins(:payment, claim: :encounter).
        where(payments: { organization_id: org.id, payment_status: Payment.payment_statuses[:succeeded] }).
        order("payments.created_at DESC").
        limit(200)

      days = sample_allocations.map do |pa|
        pay = pa.payment
        enc = pa.claim&.encounter
        paid_on = (pay.payment_date || pay.created_at)&.to_date
        service_on = (enc&.date_of_service || pa.claim&.created_at)&.to_date
        next unless paid_on && service_on
        (paid_on - service_on).to_i
      end.compact

      @avg_days_to_payment = days.any? ? (days.sum.to_f / days.size).round : 0
    rescue
      @avg_days_to_payment = 0
    end

    # Claim percentages - this month
    month_start = today.beginning_of_month
    month_end   = today.end_of_month
    month_claims = claims.where(created_at: month_start..month_end)
    month_total = month_claims.count
    month_paid  = month_claims.paid_in_full.count
    month_denied = month_claims.denied.count
    month_outstanding = [ month_total - month_paid - month_denied, 0 ].max

    if month_total.positive?
      @paid_claim_rate      = (month_paid * 100.0 / month_total).round
      @denial_rate          = (month_denied * 100.0 / month_total).round
      @outstanding_percent  = (month_outstanding * 100.0 / month_total).round
    else
      @paid_claim_rate = @denial_rate = @outstanding_percent = 0
    end

    # Previous 7-day lookback (recent payments)
    lookback_start = 7.days.ago.beginning_of_day
    @recent_payments_7d = payments.
      where("payment_date >= ? OR (payment_date IS NULL AND created_at >= ?)", lookback_start.to_date, lookback_start).
      order(Arel.sql("COALESCE(payment_date, created_at) DESC")).
      includes(payment_applications: { claim: [ :encounter, :patient ] }).
      limit(10)
  end

  def calculate_growth(model, since)
    total = model.count
    recent = model.where("created_at > ?", since).count
    return 0 if total == 0

    ((recent.to_f / total) * 100).round(1)
  end
end
