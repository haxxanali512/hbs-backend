class Users::SessionsController < Devise::SessionsController
  layout "devise"

  def create
    super do |resource|
        if resource.persisted?
          Rails.logger.info "User #{resource.email} signed in successfully"
          # Rails.logger.info "User role: #{resource.role&.name}"
          Rails.logger.info "User admin status: #{resource.admin?}"
          Rails.logger.info "Redirect path: #{after_sign_in_path_for(resource)}"
          Rails.logger.info "Session after sign-in: #{session.to_hash}"
          Rails.logger.info "Current user after sign-in: #{current_user&.email}"
          Rails.logger.info "User signed in after sign-in: #{user_signed_in?}"
        else
          Rails.logger.warn "Sign in failed for #{resource.email}: #{resource.errors.full_messages}"
        end
    end
  end
end
