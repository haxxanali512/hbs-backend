# Runs Xano prescription import in the background (e.g. 5000 records).
# Logs progress via XanoPrescriptionImportService; check production logs for "[XanoPrescriptionImport]".
class XanoPrescriptionImportJob < ApplicationJob
  queue_as :default

  def perform(api_url: nil)
    Rails.logger.info "[XanoPrescriptionImport] Job started"
    result = XanoPrescriptionImportService.new(api_url: api_url).call
    Rails.logger.info "[XanoPrescriptionImport] Job finished created=#{result[:created]} errors=#{result[:errors].size}"
  rescue XanoPrescriptionImportService::Error => e
    Rails.logger.error "[XanoPrescriptionImport] Job failed: #{e.message}"
    raise
  end
end
