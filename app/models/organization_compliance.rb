class OrganizationCompliance < ApplicationRecord
  audited

  belongs_to :organization

  # Validation for document signing
  validate :terms_must_be_accepted, on: :document_signing

  private

  def terms_must_be_accepted
    unless terms_of_use? && privacy_policy_accepted?
      errors.add(:base, "Both Terms of Service and Privacy Policy must be accepted")
    end
  end
end
