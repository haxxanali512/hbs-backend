class ReferralPartners::ApplicationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create ]
  skip_before_action :has_access?, only: [ :new, :create ]

  def new
    @referral_partner = ReferralPartner.new
  end

  def create
    @referral_partner = ReferralPartner.new(application_params)
    @referral_partner.status = :pending

    if duplicate_application?
      @referral_partner.errors.add(:email, "has already been used for a referral partner application")
      render :new, status: :unprocessable_entity
      return
    end

    if @referral_partner.save
      NotificationService.notify_referral_partner_application_submitted(@referral_partner)
      redirect_to new_referral_partners_application_path, notice: "Application submitted successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def application_params
    params.require(:referral_partner).permit(:first_name, :last_name, :email, :phone, :partner_type)
  end

  def duplicate_application?
    ReferralPartner.where("LOWER(email) = ?", @referral_partner.email.to_s.downcase.strip)
                   .where(status: [ ReferralPartner.statuses[:pending], ReferralPartner.statuses[:approved] ])
                   .exists?
  end
end
