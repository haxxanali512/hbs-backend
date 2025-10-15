namespace :billing do
  desc "Run month-end billing now"
  task month_end: :environment do
    period = (Time.current.beginning_of_month - 1.day).beginning_of_month..(Time.current.beginning_of_month - 1.day).end_of_month
    Organization.find_each do |org|
      next unless org.organization_billing&.stripe? && org.organization_billing&.active?
      result = MonthlyBillingService.charge!(org.id, period: period)
      puts "Billed org=#{org.id} success=#{result[:success]}#{" error=#{result[:error]}" unless result[:success]}"
    end
  end
end
