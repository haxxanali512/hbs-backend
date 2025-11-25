namespace :email_templates do
  desc "Sync email template registry defaults into the database"
  task sync_defaults: :environment do
    EmailTemplateRegistry.all.each do |template|
      record = EmailTemplateKey.find_or_initialize_by(key: template.key)
      record.name = template.name
      record.description = template.description
      record.default_subject = template.default_subject
      record.default_body_html = template.default_body_html
      record.default_body_text = template.default_body_text
      record.default_locale = template.default_locale || "en"
      record.active = true if record.new_record?

      if record.changed?
        record.save!
        puts "[EmailTemplates] Synced #{template.key}"
      else
        puts "[EmailTemplates] Up-to-date #{template.key}"
      end
    end
  end
end

