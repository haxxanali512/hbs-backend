class Tenant::ResourcesController < Tenant::BaseController
  def index
    @resources = Resource.published.featured_first
    @resources = @resources.by_type(params[:resource_type]) if params[:resource_type].present?
    @resources = @resources.search(params[:search]) if params[:search].present?
    if params[:tag].present?
      tag = params[:tag].to_s.strip
      @resources = @resources.where("tags ILIKE ?", "%#{tag}%")
    end

    @pagy, @resources = pagy(@resources, items: 20)

    @search_placeholder = "Search resources..."
    @custom_selects = Array(@custom_selects) + [
      {
        param: :resource_type,
        label: "Type",
        options: [["All Types", ""]] + Resource::RESOURCE_TYPES.map { |t| [t.titleize, t] }
      }
    ]
    @custom_inputs = Array(@custom_inputs) + [
      {
        param: :tag,
        label: "Tag",
        placeholder: "Filter by tag"
      }
    ]
  end

  def show
    @resource = Resource.published.find(params[:id])
  end
end

