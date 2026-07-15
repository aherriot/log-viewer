module LogsHelper
  def sort_link(text, column, current_sort, current_dir)
    next_dir = (current_sort == column && current_dir != "desc") ? "desc" : "asc"
    link = link_to text, logs_path(request.query_parameters.merge(sort: column, dir: next_dir, page: nil))
    return link unless current_sort == column

    safe_join([link, " ", current_dir == "desc" ? "▼" : "▲"])
  end
end
