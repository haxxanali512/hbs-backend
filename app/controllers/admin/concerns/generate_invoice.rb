module Admin
  module Concerns
    module GenerateInvoice
      def generate_invoice_pdf(invoice)
        require "pdfkit"

        html = ApplicationController.render(
          template: "reports/invoices/invoice",
          layout: "pdf",
          assigns: { invoice: invoice, payments: invoice.payments.order(created_at: :desc) }
        )

        # Inline compiled CSS from Sprockets (dev) or public/assets (prod)
        css_content = nil
        begin
          # Development: Sprockets server provides logical assets
          if Rails.application.assets
            %w[application application.css tailwind.css tailwind/application.css].each do |logical|
              asset = Rails.application.assets.find_asset(logical)
              if asset
                css_content = asset.to_s
                break
              end
            end
          end

          # Production or when assets pipeline not in memory
          if css_content.blank?
            manifest_path = Rails.root.join("public", "assets", ".sprockets-manifest-*.json")
            manifest_file = Dir[manifest_path].max
            if manifest_file
              manifest = JSON.parse(File.read(manifest_file)) rescue {}
              %w[tailwind.css application.css].each do |logical|
                digest_name = (manifest["assets"] || {})[logical]
                next unless digest_name
                candidate = Rails.root.join("public", "assets", digest_name)
                if File.exist?(candidate)
                  css_content = File.read(candidate)
                  break
                end
              end
            end
          end
        rescue => _e
          # ignore; we'll proceed without CSS if unavailable
        end

        html = html.sub("</head>", "\n<style>\n#{css_content}\n</style>\n</head>") if css_content.present?

        kit = PDFKit.new(
          html,
          PDFKit.configuration.default_options.merge(
            enable_local_file_access: true,
            quiet: false,
            margin_top: "6mm",
            margin_right: "6mm",
            margin_bottom: "6mm",
            margin_left: "6mm"
          )
        )

        kit.to_pdf
      end
    end
  end
end
