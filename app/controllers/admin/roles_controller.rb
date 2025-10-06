class Admin::RolesController < ::ApplicationController
  before_action :set_role, only: %i[ show edit update destroy ]
  before_action :prevent_super_admin_modification, only: %i[ edit update destroy ]

  def index
    @roles = Role.order(:role_name)
  end

  def show
    redirect_to edit_admin_role_path(@role)
  end

  def new
    @role = Role.new(access: HbsCustoms::ModulePermission.data.deep_symbolize_keys)
    @permissions = normalize_permissions(@role.access)
  end

  def edit
    # Ensure all modules appear, even if missing in stored JSON
    merged = HbsCustoms::ModulePermission.data
      .deep_merge((@role.access || {}).deep_symbolize_keys)
      .deep_symbolize_keys
    @permissions = normalize_permissions(merged)
  end

  def create
    @role = Role.new(role_params)
    if @role.save
      redirect_to admin_roles_path, notice: "Role created successfully."
    else
      @role.access ||= HbsCustoms::ModulePermission.data.deep_symbolize_keys
      @permissions = normalize_permissions(@role.access)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @role.update(role_params)
      redirect_to admin_roles_path, notice: "Role updated successfully."
    else
      merged = HbsCustoms::ModulePermission.data
        .deep_merge((@role.access || {}).deep_symbolize_keys)
        .deep_symbolize_keys
      @permissions = normalize_permissions(merged)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @role.destroy
      redirect_to admin_roles_path, notice: "Role deleted.", status: :see_other
    else
      redirect_to admin_roles_path, alert: "Role deletion failed."
    end
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def prevent_super_admin_modification
    return unless @role.role_name.to_s.strip.casecmp("Super Admin").zero?
    redirect_to admin_roles_path, alert: "Super Admin role cannot be modified."
  end

  # Permit nested access structure like access[accounts][employees][index]=1
  def role_params
    permitted = params.require(:role).permit(:role_name)
    permitted[:access] = extract_access(params[:role][:access]) if params.dig(:role, :access)
    permitted
  end

  def extract_access(raw)
    # Convert "1"/"0" to booleans and ensure full nested hash
    case raw
    when ActionController::Parameters
      raw.to_unsafe_h.transform_values { |v| extract_access(v) }
    when Hash
      raw.transform_values { |v| extract_access(v) }
    else
      ActiveModel::Type::Boolean.new.cast(raw)
    end
  end

  def normalize_permissions(hash)
    bool = ActiveModel::Type::Boolean.new
    (hash || {}).each_with_object({}) do |(mod_key, submods), acc|
      acc[mod_key] = {}
      (submods || {}).each do |sub_key, actions|
        acc[mod_key][sub_key] = {}
        (actions || {}).each do |action, val|
          acc[mod_key][sub_key][action] = bool.cast(val)
        end
      end
    end
  end
end
