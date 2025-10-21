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
  end

  def create
      random_password = SecureRandom.uuid

      @user = User.new(
        invite_params.except(:organizations_attributes).merge(
          password: random_password,
          password_confirmation: random_password,
          invited_by: current_user,
          status: "pending"
        )
      )

      @organization = Organization.new(
            name: invite_params[:organizations_attributes]["name"],
            subdomain: invite_params[:organizations_attributes]["subdomain"],
            owner: @user
          )


    if invite_params[:organizations_attributes].present?
      if @user.save && @organization.save
        @organization.add_member(@user, nil)
        redirect_to admin_users_path, notice: "Invitation sent successfully." and return
      else
        flash[:alert] = @user.errors.full_messages.to_sentence
        @roles = Role.order(:role_name)
        render :new
      end
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
  end

  def send_invitation
    @user = User.invite!(invite_params, current_user)
    if @user.errors.empty?
      redirect_to admin_users_path, notice: "Invitation sent successfully."
    else
      @roles = Role.order(:role_name)
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
    params.require(:user).permit(:email, :role_id, :first_name, :last_name, :username, organizations_attributes: [ :name, :subdomain ])
  end

  def authorize_user
    authorize @user
  end
end
