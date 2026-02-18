namespace :xano do
  desc "Pull patients from Xano patient_pull_data API and create under matching organizations (by Organization_Name)"
  task patient_pull: :environment do
    # Send logs to stdout so you see output when running: rails xano:patient_pull
    Rails.logger = ActiveSupport::Logger.new($stdout)
    Rails.logger.level = Logger::INFO
    Rails.logger.formatter = proc do |severity, datetime, _progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end

    url = ENV["XANO_PATIENT_PULL_URL"].presence
    result = XanoPatientPullService.new(api_url: url).call

    puts ""
    puts "Summary: Created=#{result[:created]}, Skipped=#{result[:skipped]}, Errors=#{result[:errors].size}"
    result[:errors].each { |e| puts "  - #{e}" } if result[:errors].any?
  end
end
