class Log < ApplicationRecord
  # Full-text search over `message` via the generated `search_vector` column.
  # `websearch_to_tsquery` accepts loose, user-typed search syntax (quoted
  # phrases, "or", leading "-" to exclude) without raising on malformed input,
  # unlike `to_tsquery` — the right choice for a search box.
  def self.search(query)
    return order(created_at: :desc) if query.blank?

    tsquery_sql = sanitize_sql_array(["websearch_to_tsquery('english', ?)", query])

    select("logs.*, ts_rank(search_vector, #{tsquery_sql}) AS rank")
      .where("search_vector @@ #{tsquery_sql}")
      .order("rank DESC")
  end

  # Range filter on created_at, backed by the BRIN index — from/to are
  # user-typed strings (e.g. from a date input), parsed defensively since
  # they may be blank or malformed.
  scope :in_time_range, ->(from, to) {
    scope = all
    if from.present? && (parsed = Time.zone.parse(from) rescue nil)
      scope = scope.where("created_at >= ?", parsed)
    end
    if to.present? && (parsed = Time.zone.parse(to) rescue nil)
      scope = scope.where("created_at <= ?", parsed)
    end
    scope
  }

  # Exact IP match inside the metadata jsonb blob, backed by the GIN index.
  scope :with_ip, ->(ip) {
    return all if ip.blank?

    where("metadata @> ?", { ip: ip }.to_json)
  }

  # Matches index_logs_on_status_server_error's predicate exactly, so the
  # planner can actually use that partial index. Any other status value
  # filtered through here would fall back to a Seq Scan.
  scope :server_errors_only, ->(flag) {
    return all unless ActiveModel::Type::Boolean.new.cast(flag)

    where(status: "server_error")
  }
end
