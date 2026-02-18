namespace :xano do
  desc "Pull patients from Xano patient_pull_data API and create under matching organizations (by Organization_Name)"
  task patient_pull: :environment do
    url = ENV["XANO_PATIENT_PULL_URL"].presence
    result = XanoPatientPullService.new(api_url: url).call
    puts "Created: #{result[:created]}, Skipped (existing): #{result[:skipped]}, Errors: #{result[:errors].size}"
    result[:errors].each { |e| puts "  - #{e}" } if result[:errors].any?
  end
end
