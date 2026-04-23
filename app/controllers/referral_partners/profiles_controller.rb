class ReferralPartners::ProfilesController < ReferralPartners::BaseController
  def show
    @referral_partner = current_referral_partner
  end

  def edit
    @referral_partner = current_referral_partner
  end

  def update
    @referral_partner = current_referral_partner
    if @referral_partner.update(profile_params)
      redirect_to referral_partners_profile_path, notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:referral_partner).permit(:first_name, :last_name, :phone, :tax_form_status, :notes)
  end
end
