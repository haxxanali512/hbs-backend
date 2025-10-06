class Admin::UsersController < ::ApplicationController
  before_action :set_user, only: [ :show, :edit, :update, :destroy, :suspend, :activate, :deactivate, :unlock, :reset_password, :change_role, :audit_logs, :sessions ]

  def index
    @users = policy_scope(User).includes(:role, :user_status_logs)
                              .order(created_at: :desc)
                              .page(params[:page])

    # Filtering
    @users = @users.where(status: params[:status]) if params[:status].present?
    @users = @users.where(role_id: params[:role_id]) if params[:role_id].present?
    @users = @users.where("email ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    @roles = Role.active.order(:name)
    @statuses = User.statuses.keys
  end

  def show
    @recent_logs = @user.user_status_logs.recent.limit(10)
    @recent_sessions = @user.sessions.recent.limit(5)
  end

  def new
    @user = User.new
    @roles = Role.active.order(:name)
  end

  def create
    @user = User.new(user_params)
    @user.password = SecureRandom.hex(8) # Generate random password
    @user.skip_confirmation! if @user.respond_to?(:skip_confirmation!)

    if @user.save
      # Send invitation email
      UserMailer.invitation_instructions(@user, @user.password).deliver_now

      redirect_to admin_user_path(@user), notice: "User created successfully and invitation sent."
    else
      @roles = Role.active.order(:name)
      render :new
    end
  end

  def edit
    @roles = Role.active.order(:name)
  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "User updated successfully."
    else
      @roles = Role.active.order(:name)
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
      redirect_to admin_user_path(@user), alert: "Cannot suspend super admin accounts."
    else
      @user.suspend!(params[:reason], changed_by: current_user)
      redirect_to admin_user_path(@user), notice: "User suspended successfully."
    end
  end

  def activate
    @user.activate!(changed_by: current_user)
    redirect_to admin_user_path(@user), notice: "User activated successfully."
  end

  def deactivate
    if @user.super_admin?
      redirect_to admin_user_path(@user), alert: "Cannot deactivate super admin accounts."
    else
      @user.deactivate!(params[:reason], changed_by: current_user)
      redirect_to admin_user_path(@user), notice: "User deactivated successfully."
    end
  end

  def unlock
    @user.unlock_account!
    redirect_to admin_user_path(@user), notice: "User account unlocked successfully."
  end

  def reset_password
    @user.send_reset_password_instructions
    redirect_to admin_user_path(@user), notice: "Password reset instructions sent."
  end

  def change_role
    if @user.super_admin?
      redirect_to admin_user_path(@user), alert: "Cannot change super admin role."
    else
      @user.update!(role_id: params[:role_id])
      redirect_to admin_user_path(@user), notice: "User role updated successfully."
    end
  end

  def invite
    @user = User.new
    @roles = Role.active.order(:name)
  end

  def send_invitation
    @user = User.invite!(invite_params, current_user)

    if @user.errors.empty?
      redirect_to admin_users_path, notice: "Invitation sent successfully."
    else
      @roles = Role.active.order(:name)
      render :invite
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :phone_number, :role_id, :status)
  end

  def invite_params
    params.require(:user).permit(:email, :role_id)
  end
end
