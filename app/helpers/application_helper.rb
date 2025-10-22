module ApplicationHelper
  include Pagy::Frontend

  # Helper method to render status badges
  def status_badge(status, options = {})
    badge_classes = case status.to_s
    when "active", "approved", "paid"
      "bg-green-100 text-green-800"
    when "pending", "draft"
      "bg-yellow-100 text-yellow-800"
    when "inactive", "rejected", "voided"
      "bg-red-100 text-red-800"
    when "suspended"
      "bg-orange-100 text-orange-800"
    else
      "bg-gray-100 text-gray-800"
    end

    content_tag :span, status.humanize, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{badge_classes}"
  end

  # Helper method for audit action badge colors
  def audit_action_badge_color(action)
    case action.to_s
    when "create"
      "bg-green-100 text-green-800"
    when "update"
      "bg-blue-100 text-blue-800"
    when "destroy"
      "bg-red-100 text-red-800"
    when "destroy_soft"
      "bg-orange-100 text-orange-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # Helper method to format currency
  def format_currency(amount)
    number_to_currency(amount, precision: 2)
  end

  # Helper method to format date
  def format_date(date, format = :short)
    return "—" if date.blank?
    date.strftime(format == :short ? "%b %d, %Y" : "%B %d, %Y at %I:%M %p")
  end

  # Helper method to truncate text
  def truncate_text(text, length = 50)
    return "—" if text.blank?
    text.length > length ? "#{text[0...length]}..." : text
  end

  # Helper method for pagination info
  def pagination_info(pagy)
    return unless pagy
    "Showing #{pagy.from} to #{pagy.to} of #{pagy.count} entries"
  end
end
