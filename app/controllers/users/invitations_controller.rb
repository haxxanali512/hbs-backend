class Users::InvitationsController < Devise::InvitationsController
  # Use the same redirect logic as sign in after accepting an invitation
  def after_accept_path_for(resource)
    redirect_to new_user_session_path
  end

  private

  def accept_invitation_params
    params.require(resource_name).permit(:invitation_token, :username, :password, :password_confirmation)
  end
end
