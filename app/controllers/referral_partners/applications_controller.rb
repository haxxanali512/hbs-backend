module ReferralPartners
  class ApplicationsController < ApplicationController
    skip_before_action :authenticate_user!, only: [ :new, :create ]
    skip_before_action :has_access?, only: [ :new, :create ]

    def new
      @referral_partner = ::ReferralPartner.new(email: params[:ref].presence)
      @submitted = params[:submitted].present?
    end

    def create
      @referral_partner = ::ReferralPartner.new(application_params.merge(status: :pending))

      if duplicate_application?
        @referral_partner.errors.add(:email, "already has a pending or approved application")
        render :new, status: :unprocessable_entity
        return
      end

      if @referral_partner.save
        NotificationService.notify_referral_partner_application_submitted(@referral_partner)
        redirect_to referral_root_path(submitted: 1)
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def application_params
      full_name = params.dig(:referral_partner, :full_name).to_s.strip
      first_name, *rest = full_name.split
      last_name = rest.join(" ")

      params.require(:referral_partner).permit(:email, :phone, :partner_type).merge(
        first_name: first_name,
        last_name: last_name
      )
    end

    def duplicate_application?
      ::ReferralPartner.where("LOWER(email) = ?", @referral_partner.email.to_s.downcase)
                       .where(status: [ :pending, :approved ])
                       .exists?
    end
  end
end
