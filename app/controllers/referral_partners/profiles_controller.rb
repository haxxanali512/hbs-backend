module ReferralPartners
  class ProfilesController < BaseController
    def show; end

    def edit; end

    def update
      if current_referral_partner.update(profile_params)
        redirect_to referral_partner_profile_path, notice: "Profile updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def profile_params
      params.require(:referral_partner).permit(:first_name, :last_name, :phone, :tax_form_status, :notes)
    end
  end
end
