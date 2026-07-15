module LogsHelper
  def sort_link(text, column, current_sort, current_dir)
    next_dir = (current_sort == column && current_dir != "desc") ? "desc" : "asc"
    link = link_to text, logs_path(request.query_parameters.merge(sort: column, dir: next_dir, page: nil))
    return link unless current_sort == column

    safe_join([link, " ", current_dir == "desc" ? "▼" : "▲"])
  end

  # Wraps a filter input with a small "×" button that clears just that field
  # (via the auto-submit Stimulus controller) and resubmits. The button is
  # always rendered (reserving its space) but hidden via CSS when the field
  # is blank, so its appearance/disappearance never changes column width.
  def field_with_clear(field_name, value, &block)
    content_tag(:div, class: "field-row") do
      classes = ["clear-btn"]
      classes << "invisible" unless value.present?

      safe_join([
        capture(&block),
        button_tag("×", type: "button", class: classes.join(" "), title: "Clear #{field_name}",
          data: { action: "click->auto-submit#clearField", auto_submit_field_param: field_name })
      ])
    end
  end
end
