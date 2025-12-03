class PrescriptionExpiryJob < ApplicationJob
  queue_as :default

  # This job should be scheduled to run daily at midnight UTC
  def perform
    Prescription.active.where("expires_on < ? OR expires_on = ?", Date.current, Date.current).find_each do |prescription|
      prescription.update!(expired: true)
    end
  end
end


