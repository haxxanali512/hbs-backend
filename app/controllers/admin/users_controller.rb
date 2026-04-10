class Admin::UsersController < ::ApplicationController
  before_action :set_user, only: [ :edit, :update, :destroy, :hard_destroy, :suspend, :activate, :deactivate, :unlock, :reset_password, :reinvite, :change_role ]

  def index
    @users = User.with_discarded.includes(:role).order(created_at: :desc)
    @users = @users.where(role_id: params[:role_id]) if params[:role_id].present?
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @users = @users.where("email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?", search_term, search_term, search_term)
    end

    case params[:archived]
    when "archived"
      @users = @users.discarded
    when "all"
      # no-op, already with_discarded
    else
      @users = @users.kept
    end

    @pagy, @users = pagy(@users, items: 20)
    @roles = Role.order(:role_name)
  end


  def new
    @user = User.new
    @roles = Role.order(:role_name)
    @organizations = Organization.kept.order(:name)
  end

  def create
    if invite_user_and_attach_organization!
      redirect_to admin_users_path, notice: "User created and invitation sent successfully."
    else
      @roles = Role.order(:role_name)
      @organizations = Organization.kept.order(:name)
      render :new
    end
  end


  def edit
    @roles = Role.order(:role_name)
  end

  def update
    # Apply lock/unlock toggle from edit form
    if params.dig(:user, :locked).present?
      should_lock = ActiveModel::Type::Boolean.new.cast(params[:user][:locked])
      if should_lock && !@user.access_locked?
        @user.lock_access!
      elsif !should_lock && @user.access_locked?
        @user.unlock_access!
      end
    end

    if @user.update(user_params)
      redirect_to admin_users_path, notice: "User updated successfully."
    else
      @roles = Role.order(:role_name)
      render :edit
    end
  end

  def destroy
    if @user == current_user
      redirect_to admin_users_path, alert: "You cannot delete your own account."
    elsif @user.super_admin?
      redirect_to admin_users_path, alert: "Cannot delete super admin accounts."
    else
      @user.discard
      redirect_to admin_users_path, notice: "User deleted successfully."
    end
  end

  def hard_destroy
    unless current_user&.permissions_for("admin", "users", "hard_destroy")
      redirect_to admin_users_path, alert: "Only users with the 'Hard Delete' permission can permanently delete users."
      return
    end

    if @user == current_user
      redirect_to admin_users_path, alert: "You cannot delete your own account."
      return
    end

    if @user.super_admin?
      redirect_to admin_users_path, alert: "Cannot permanently delete super admin accounts."
      return
    end

    @user.destroy!
    redirect_to admin_users_path, notice: "User and all related data permanently deleted."
  rescue => e
    redirect_to admin_users_path, alert: "Could not permanently delete user: #{e.message}"
  end

  def suspend
    if @user.super_admin?
      redirect_to admin_users_path, alert: "Cannot suspend super admin accounts."
    else
      @user.suspend!(params[:reason], changed_by: current_user)
      redirect_to admin_users_path, notice: "User suspended successfully."
    end
  end

  def activate
    @user.activate!(changed_by: current_user)
    redirect_to admin_users_path, notice: "User activated successfully."
  end

  def deactivate
    if @user.super_admin?
      redirect_to admin_users_path, alert: "Cannot deactivate super admin accounts."
    else
      @user.deactivate!(params[:reason], changed_by: current_user)
      redirect_to admin_users_path, notice: "User deactivated successfully."
    end
  end

  def unlock
    @user.unlock_access!
    redirect_to admin_users_path, notice: "User account unlocked successfully."
  end

  def reset_password
    @user.send_reset_password_instructions
    redirect_to admin_users_path, notice: "Password reset instructions sent."
  end

  def reinvite
    @user.invite!
    redirect_to admin_users_path, notice: "Invitation resent successfully."
  end

  def change_role
    if @user.super_admin?
      redirect_to admin_users_path, alert: "Cannot change super admin role."
    else
      @user.update!(role_id: params[:role_id])
      redirect_to admin_users_path, notice: "User role updated successfully."
    end
  end

  def invite
    @user = User.new
    @roles = Role.order(:role_name)
    @organizations = Organization.kept.order(:name)
  end

  def quick_create
    password = SecureRandom.uuid
    @user = User.new(quick_create_params.merge(
      password: password,
      password_confirmation: password,
      status: "pending"
    ))
    if @user.save
      render json: {
        id: @user.id,
        display_name: @user.display_name,
        email: @user.email,
        label: "#{@user.display_name} (#{@user.email})"
      }, status: :created
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def send_invitation
    if invite_user_and_attach_organization!
      redirect_to admin_users_path, notice: "Invitation sent successfully."
    else
      @roles = Role.order(:role_name)
      @organizations = Organization.kept.order(:name)
      render :invite
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :username, :role_id)
  end

  def quick_create_params
    params.require(:user).permit(:email, :first_name, :last_name, :username)
  end

  def invite_params
    params.require(:user).permit(
      :email,
      :role_id,
      :first_name,
      :last_name,
      :username,
      :invite_organization_mode,
      :organization_id,
      organizations_attributes: [ :name, :subdomain ]
    )
  end

  # Devise Invitable sends the invitation email from User.invite! by default.
  # We defer delivery until after organization membership/ownership exists so
  # invitation_instructions can build accept_user_invitation_url on
  # subdomain.localhost (tenant) instead of falling back to admin.
  def invite_user_and_attach_organization!
    mode = invite_params[:invite_organization_mode]
    organization_id = invite_params[:organization_id]
    org_attrs = invite_params[:organizations_attributes] || {}

    user_attrs = invite_params
      .except(:organizations_attributes, :invite_organization_mode, :organization_id)
      .merge(status: :pending, skip_invitation: true)

    @user = User.invite!(user_attrs, current_user)
    return false if @user.errors.any?

    attach_invited_user_to_organization!(@user, mode: mode, organization_id: organization_id, org_attrs: org_attrs)
    @user.deliver_invitation
    true
  end

  def attach_invited_user_to_organization!(user, mode:, organization_id:, org_attrs:)
    case mode.to_s
    when "none"
      nil
    when "existing"
      if organization_id.present?
        org = Organization.kept.find_by(id: organization_id)
        org&.add_member(user, nil)
      end
    when "new"
      nested = organization_attributes_hash(org_attrs)
      if nested[:name].present? && nested[:subdomain].present?
        org = Organization.new(
          name: nested[:name],
          subdomain: nested[:subdomain],
          owner: user
        )
        if org.save
          org.add_member(user, nil)
        end
      end
    end
  end

  # fields_for :organizations_attributes often submits { "0" => { "name" => ... } }
  def organization_attributes_hash(org_attrs)
    return {} if org_attrs.blank?

    raw = parameters_to_hash(org_attrs)
    h = raw.with_indifferent_access
    return h if h[:name].present? || h[:subdomain].present?

    nested = raw.values.find { |v| v.is_a?(Hash) || v.is_a?(ActionController::Parameters) }
    parameters_to_hash(nested || {}).with_indifferent_access
  end

  def parameters_to_hash(value)
    case value
    when ActionController::Parameters
      value.to_unsafe_h
    when Hash
      value
    else
      {}
    end
  end

  def authorize_user
    authorize @user
  end
end
