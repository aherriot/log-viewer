module LogsHelper
  def sort_link(text, column, current_sort, current_dir)
    next_dir = (current_sort == column && current_dir != "desc") ? "desc" : "asc"
    link = link_to text, logs_path(request.query_parameters.merge(sort: column, dir: next_dir, page: nil))
    return link unless current_sort == column

    safe_join([link, " ", current_dir == "desc" ? "▼" : "▲"])
  end

  # Wraps a filter input with a small "×" button that clears just that field
  # (via the auto-submit Stimulus controller) and resubmits. Only rendered
  # when the field currently has a value.
  def field_with_clear(field_name, value, &block)
    content_tag(:div, class: "field-row") do
      parts = [capture(&block)]
      if value.present?
        parts << button_tag("×", type: "button", class: "clear-btn", title: "Clear #{field_name}",
          data: { action: "click->auto-submit#clearField", auto_submit_field_param: field_name })
      end
      safe_join(parts)
    end
  end
end
