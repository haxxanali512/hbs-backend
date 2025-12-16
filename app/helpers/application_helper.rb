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

  # Tailwind-styled Pagy navigation, used by all index pages
  def pagy_nav(pagy)
    return if pagy.pages <= 1

    html = +""
    html << %(<nav class="pagy-nav flex items-center space-x-2" aria-label="Pagination">)

    # Base params for links (preserve current query params)
    base_params = request.query_parameters.symbolize_keys
    page_param  = (pagy.respond_to?(:vars) && pagy.vars[:page_param]) || :page

    # Previous button
    if pagy.prev
      prev_url = url_for(base_params.merge(page_param => pagy.prev, only_path: true))
      html << link_to(
        "&laquo;".html_safe,
        prev_url,
        "aria-label" => "Previous",
        class: "inline-flex items-center justify-center w-8 h-8 rounded-full border border-gray-300 bg-white text-xs text-gray-700 hover:bg-gray-50"
      )
    else
      html << %(<span class="inline-flex items-center justify-center w-8 h-8 rounded-full border border-gray-200 bg-gray-100 text-xs text-gray-400 cursor-default" aria-disabled="true">&laquo;</span>)
    end

    # Page numbers
    pagy.series.each do |item|
      case item
      when Integer
        if item == pagy.page
          html << %(<span class="inline-flex items-center justify-center w-8 h-8 rounded-full border border-indigo-500 bg-indigo-50 text-xs font-semibold text-indigo-700 cursor-default" aria-current="page">#{item}</span>)
        else
          page_url = url_for(base_params.merge(page_param => item, only_path: true))
          html << link_to(
            item.to_s,
            page_url,
            "aria-label" => "Page #{item}",
            class: "inline-flex items-center justify-center w-8 h-8 rounded-full border border-gray-300 bg-white text-xs text-gray-700 hover:bg-gray-50"
          )
        end
      when :gap
        html << %(<span class="inline-flex items-center justify-center w-8 h-8 rounded-full text-xs text-gray-400 cursor-default">…</span>)
      end
    end

    # Next button
    if pagy.next
      next_url = url_for(base_params.merge(page_param => pagy.next, only_path: true))
      html << link_to(
        "&raquo;".html_safe,
        next_url,
        "aria-label" => "Next",
        class: "inline-flex items-center justify-center w-8 h-8 rounded-full border border-gray-300 bg-white text-xs text-gray-700 hover:bg-gray-50"
      )
    else
      html << %(<span class="inline-flex items-center justify-center w-8 h-8 rounded-full border border-gray-200 bg-gray-100 text-xs text-gray-400 cursor-default" aria-disabled="true">&raquo;</span>)
    end

    html << "</nav>"
    html.html_safe
  end
end
