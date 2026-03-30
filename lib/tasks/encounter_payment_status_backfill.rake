namespace :encounters do
  desc "Backfill payment-driven encounter statuses for encounters with payments"
  task backfill_payment_status_sync: :environment do
    scope = Encounter.kept.joins(:payment_applications).distinct
    total = scope.count
    updated = 0

    puts "Backfilling payment status sync for #{total} encounters..."

    scope.find_each(batch_size: 200) do |encounter|
      before = [
        encounter.payment_status,
        encounter.total_paid_amount.to_d,
        encounter.payment_date,
        encounter.internal_status,
        encounter.tenant_status,
        encounter.shared_status
      ]

      encounter.recalculate_payment_summary!
      encounter.reload

      after = [
        encounter.payment_status,
        encounter.total_paid_amount.to_d,
        encounter.payment_date,
        encounter.internal_status,
        encounter.tenant_status,
        encounter.shared_status
      ]

      updated += 1 if before != after
    end

    puts "Backfill complete. Updated #{updated} / #{total} encounters."
  end
end
