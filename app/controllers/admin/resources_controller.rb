class Admin::ResourcesController < Admin::BaseController
  before_action :set_resource, only: %i[show edit update destroy]

  def index
    @resources = Resource.order(featured: :desc, created_at: :desc)
    @resources = @resources.by_type(params[:resource_type]) if params[:resource_type].present?
    @resources = @resources.where(status: params[:status]) if params[:status].present?
    @resources = @resources.search(params[:search]) if params[:search].present?

    @pagy, @resources = pagy(@resources, items: 20)

    @search_placeholder = "Title, description, tags..."
    @status_options = Resource.statuses.keys
    @custom_selects = Array(@custom_selects) + [
      {
        param: :resource_type,
        label: "Type",
        options: [["All Types", ""]] + Resource::RESOURCE_TYPES.map { |t| [t.titleize, t] }
      }
    ]
  end

  def show; end

  def new
    @resource = Resource.new
  end

  def create
    @resource = Resource.new(resource_params)
    @resource.status = :published
    attach_file

    if @resource.save
      redirect_to admin_resource_path(@resource), notice: "Resource created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @resource.update(resource_params.merge(status: :published))
      attach_file
      redirect_to admin_resource_path(@resource), notice: "Resource updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resource.destroy!
    redirect_to admin_resources_path, notice: "Resource deleted successfully."
  end

  private

  def set_resource
    @resource = Resource.find(params[:id])
  end

  def resource_params
    params.require(:resource).permit(
      :title,
      :description,
      :resource_type,
      :url,
      :tags,
      :featured
    )
  end

  def attach_file
    upload = params.dig(:resource, :file)
    return unless upload.present?

    @resource.file.attach(upload)
  end
end

