# Preview all emails at http://localhost:3000/rails/mailers/data_import_mailer_mailer
class DataImportMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/data_import_mailer_mailer/import_complete
  def import_complete
    DataImportMailer.import_complete
  end

end
