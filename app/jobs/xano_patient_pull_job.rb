# Fetches patients from Xano patient_pull_data API and creates patients under the
# matching organization (by Organization_Name). Idempotent by external_id.
#
# Run from Rails console:
#   XanoPatientPullJob.perform_now
#   XanoPatientPullJob.perform_now(api_url: "https://...")  # optional custom URL
#
# Or enqueue:
#   XanoPatientPullJob.perform_later
#   XanoPatientPullJob.perform_later(api_url: "https://...")
#
class XanoPatientPullJob < ApplicationJob
  queue_as :default

  def perform(api_url: nil)
    Rails.logger.info "[XanoPatientPull] Job started"
    result = XanoPatientPullService.new(api_url: api_url).call
    Rails.logger.info "[XanoPatientPull] Job finished created=#{result[:created]} skipped=#{result[:skipped]} errors=#{result[:errors].size}"
    result
  rescue XanoPatientPullService::Error => e
    Rails.logger.error "[XanoPatientPull] Job failed: #{e.message}"
    raise
  end
end
