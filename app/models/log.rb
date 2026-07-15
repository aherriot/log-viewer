class Log < ApplicationRecord
  SORTABLE_COLUMNS = %w[created_at user_id http_status level status].freeze
  HTTP_STATUSES = [200, 301, 404, 500].freeze

  # Full-text search over `message` via the generated `search_vector` column.
  # `websearch_to_tsquery` accepts loose, user-typed search syntax (quoted
  # phrases, "or", leading "-" to exclude) without raising on malformed input,
  # unlike `to_tsquery` — the right choice for a search box.
  def self.search(query)
    return all if query.blank?

    tsquery_sql = sanitize_sql_array(["websearch_to_tsquery('english', ?)", query])

    select("logs.*, ts_rank(search_vector, #{tsquery_sql}) AS rank")
      .where("search_vector @@ #{tsquery_sql}")
      .order("rank DESC")
  end

  # Range filter on created_at, backed by the BRIN index. from/to are
  # plain calendar dates (no time-of-day) from date inputs; `to` is treated
  # as the end of that day so the range is inclusive of the whole day.
  scope :in_time_range, ->(from, to) {
    scope = all
    if from.present? && (parsed = Date.parse(from) rescue nil)
      scope = scope.where("created_at >= ?", parsed.beginning_of_day)
    end
    if to.present? && (parsed = Date.parse(to) rescue nil)
      scope = scope.where("created_at <= ?", parsed.end_of_day)
    end
    scope
  }

  # Matches a plain IP or a CIDR range against the real `ip` column (not the
  # jsonb copy), backed by a GiST index using inet_ops. `<<=` means
  # "contained by or equal to," so it handles an exact IP ('1.2.3.4') and a
  # subnet ('10.0.0.0/24') through the same operator.
  scope :with_ip, ->(ip) {
    return all if ip.blank?
    return none unless valid_ip_or_cidr?(ip)

    where("ip <<= ?::inet", ip)
  }

  def self.valid_ip_or_cidr?(value)
    IPAddr.new(value)
    true
  rescue IPAddr::Error
    false
  end

  def self.valid_integer?(value)
    /\A-?\d+\z/.match?(value.to_s)
  end

  # Backed by index_logs_on_status (a full index, replacing the earlier
  # partial index scoped to just "server_error" — the full index serves
  # every status value plus ORDER BY status, which the partial one couldn't).
  scope :with_status, ->(status) {
    return all if status.blank?

    where(status: status)
  }

  # Backed by index_logs_on_level, added in Phase 9.
  scope :with_level, ->(level) {
    return all if level.blank?

    where(level: level)
  }

  # user_id alone still uses index_logs_on_user_id_status_covering, since
  # user_id is that composite index's leading column.
  scope :with_user_id, ->(user_id) {
    return all if user_id.blank?

    where(user_id: user_id)
  }

  # Backed by index_logs_on_http_status.
  scope :with_http_status, ->(http_status) {
    return all if http_status.blank?

    where(http_status: http_status)
  }

  # Whitelisted against SORTABLE_COLUMNS to prevent building an arbitrary
  # column/direction fragment from user-controlled params.
  def self.sorted_by(column, direction)
    column = column.presence_in(SORTABLE_COLUMNS) || "created_at"
    direction = direction == "asc" ? "asc" : "desc"
    order(Arel.sql("#{column} #{direction}"))
  end
end
