namespace :billing do
  desc "Run month-end billing now"
  task month_end: :environment do
    period_anchor = Time.current.beginning_of_month - 1.day
    period = period_anchor.beginning_of_month..period_anchor.end_of_month

    Organization.find_each do |org|
      billing = org.organization_billing
      next unless billing&.active?
      next unless billing.stripe? || billing.gocardless? || billing.manual?

      result = MonthlyBillingService.charge!(org.id, period: period)
      puts "Billed org=#{org.id} success=#{result[:success]}#{" error=#{result[:error]}" unless result[:success]}"
    end
  end
end
