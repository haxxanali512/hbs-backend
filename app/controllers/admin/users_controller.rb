class Admin::UsersController < ::ApplicationController
  before_action :set_user, only: [ :edit, :update, :destroy, :suspend, :activate, :deactivate, :unlock, :reset_password, :reinvite, :change_role ]
  before_action :authorize_user, only: [ :edit, :update, :destroy, :suspend, :activate, :deactivate, :unlock, :reset_password, :reinvite, :change_role ]
  after_action :verify_authorized, except: [ :index ]

  def index
    @users = policy_scope(User).includes(:role).order(created_at: :desc)
    @users = @users.where(role_id: params[:role_id]) if params[:role_id].present?
    @users = @users.where("email ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @roles = Role.order(:role_name)
    authorize User
  end


  def new
    @user = User.new
    @roles = Role.order(:role_name)
    authorize @user
  end

  def create
    @user = User.invite!(invite_params.merge(invited_by: current_user))
    authorize @user
    if @user.errors.empty?
      redirect_to admin_users_path, notice: "Invitation sent successfully."
    else
      @roles = Role.order(:role_name)
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
      @user.soft_delete!
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
    params.require(:user).permit(:email, :role_id)
  end

  def authorize_user
    authorize @user
  end
end
