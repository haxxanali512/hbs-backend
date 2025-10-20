PDFKit.configure do |config|
  # Resolve wkhtmltopdf path: ENV override -> gem binary -> common system locations
  wkhtml = ENV["WKHTMLTOPDF_PATH"]
  if wkhtml.blank?
    begin
      wkhtml = Gem.bin_path("wkhtmltopdf-binary", "wkhtmltopdf")
    rescue Gem::Exception
      # ignore, try common locations
    end
  end
  if wkhtml.blank?
    [
      "/opt/homebrew/bin/wkhtmltopdf",
      "/usr/local/bin/wkhtmltopdf",
      "/usr/bin/wkhtmltopdf"
    ].each do |candidate|
      if File.exist?(candidate)
        wkhtml = candidate
        break
      end
    end
  end
  config.wkhtmltopdf = wkhtml if wkhtml.present?

  config.default_options = {
    page_size: "Letter",
    print_media_type: true,
    encoding: "UTF-8",
    enable_local_file_access: true,
    disable_smart_shrinking: false,
    margin_top: "10mm",
    margin_right: "10mm",
    margin_bottom: "10mm",
    margin_left: "10mm"
  }
end
