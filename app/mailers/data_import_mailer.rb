class DataImportMailer < ApplicationMailer
  default from: "support@holisticbusinesssolution.com"

  def import_complete(user:, model_name:, result:)
    @user = user
    @model_name = model_name
    @result = result
    @failed_rows = result[:errors] || []

    mail(
      to: @user.email,
      subject: "Data Import Complete: #{@model_name} - #{@result[:success_count]} successful, #{@result[:error_count]} failed"
    )
  end
end
