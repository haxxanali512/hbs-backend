class Users::InvitationsController < Devise::InvitationsController
  protected

  def accept_resource
    resource = resource_class.accept_invitation!(update_resource_params)

    if resource.persisted?
      resource.update!(status: :active)
    end

    resource
  rescue ActiveRecord::RecordInvalid => e
    # Return the resource with errors so form can display them
    e.record
  end

  def update_resource_params
    params.require(resource_name).permit(:invitation_token, :username, :password, :password_confirmation)
  end
end
