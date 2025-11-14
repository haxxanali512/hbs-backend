class Admin::RolesController < Admin::BaseController
  before_action :set_role, only: %i[ show edit update destroy ]
  before_action :prevent_super_admin_modification, only: %i[ edit update destroy ]

  def index
    @roles = Role.kept.order(:role_name)
  end

  def show
    redirect_to edit_admin_role_path(@role)
  end

  def new
    @role = Role.new(access: HbsCustoms::ModulePermission.data.deep_symbolize_keys)
    @permissions = normalize_permissions(@role.access)
  end

  def edit
    @permissions = normalize_permissions(@role.access)
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
      @permissions = normalize_permissions(@role.access)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @role.discard
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
    permitted = params.require(:role).permit(:role_name, :scope)
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
    base = HbsCustoms::ModulePermission.data.deep_symbolize_keys
    incoming = (hash || {}).deep_symbolize_keys

    merged = deep_merge_permissions(base, incoming)

    merged.each_with_object({}) do |(namespace, modules), acc|
      acc[namespace] = modules.each_with_object({}) do |(mod_key, actions), mods_acc|
        mods_acc[mod_key] = normalize_action_hash(actions, bool)
      end
    end
  end

  def normalize_action_hash(actions, bool)
    (actions || {}).each_with_object({}) do |(action, val), acc|
      acc[action] =
        if val.is_a?(Hash)
          normalize_action_hash(val, bool)
        else
          bool.cast(val)
        end
    end
  end

  def deep_merge_permissions(base, incoming)
    base.merge(incoming) do |_key, base_val, incoming_val|
      if base_val.is_a?(Hash) && incoming_val.is_a?(Hash)
        deep_merge_permissions(base_val, incoming_val)
      else
        incoming_val
      end
    end
  end
end
