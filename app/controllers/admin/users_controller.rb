class Admin::UsersController < ::ApplicationController
  before_action :set_user, only: [ :edit, :update, :destroy, :suspend, :activate, :deactivate, :unlock, :reset_password, :reinvite, :change_role ]

  def index
    @users = User.kept.includes(:role).order(created_at: :desc)
    @users = @users.where(role_id: params[:role_id]) if params[:role_id].present?
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @users = @users.where("email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?", search_term, search_term, search_term)
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
    random_password = SecureRandom.uuid

    mode = invite_params[:invite_organization_mode]
    organization_id = invite_params[:organization_id]
    org_attrs = invite_params[:organizations_attributes] || {}

    @user = User.new(
      invite_params.except(:organizations_attributes, :invite_organization_mode, :organization_id).merge(
        password: random_password,
        password_confirmation: random_password,
        invited_by: current_user,
        status: "pending"
      )
    )

    if @user.save
      case mode
      when "existing"
        if organization_id.present?
          org = Organization.kept.find_by(id: organization_id)
          org&.add_member(@user, nil)
        end
      when "new"
        if org_attrs.present? && org_attrs["name"].present? && org_attrs["subdomain"].present?
          org = Organization.new(
            name: org_attrs["name"],
            subdomain: org_attrs["subdomain"],
            owner: @user
          )
          if org.save
            org.add_member(@user, nil)
          end
        end
      end

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

  def send_invitation
    mode = params.dig(:user, :invite_organization_mode)
    organization_id = params.dig(:user, :organization_id)
    org_attrs = invite_params[:organizations_attributes] || {}

    # Only pass user fields to Devise invitable
    user_attrs = invite_params.except(:organizations_attributes, :invite_organization_mode, :organization_id)
    @user = User.invite!(user_attrs, current_user)

    if @user.errors.empty?
      # Handle organization assignment/creation based on mode
      case mode
      when "existing"
        if organization_id.present?
          org = Organization.kept.find_by(id: organization_id)
          org&.add_member(@user, nil)
        end
      when "new"
        if org_attrs.present? && org_attrs["name"].present? && org_attrs["subdomain"].present?
          org = Organization.new(
            name: org_attrs["name"],
            subdomain: org_attrs["subdomain"],
            owner: @user
          )
          if org.save
            org.add_member(@user, nil)
          end
        end
      end

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

  def authorize_user
    authorize @user
  end
end
