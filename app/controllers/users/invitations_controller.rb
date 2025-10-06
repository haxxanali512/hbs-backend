class Users::InvitationsController < Devise::InvitationsController
  private

  def accept_invitation_params
    params.require(resource_name).permit(:invitation_token, :username, :password, :password_confirmation)
  end
end
