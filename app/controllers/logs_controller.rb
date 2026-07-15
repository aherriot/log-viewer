class LogsController < ApplicationController
  PER_PAGE = 50

  def index
    @query = params[:q]
    @from = params[:from]
    @to = params[:to]
    @ip = params[:ip]
    @status = params[:status]
    @level = params[:level]
    @user_id = params[:user_id]
    @http_status = params[:http_status]
    @sort = params[:sort]
    @dir = params[:dir]
    @page = [ params[:page].to_i, 1 ].max

    @errors = validate_filters

    if @errors.any?
      @logs = []
      @has_next = false
    else
      run_query
    end

    respond_to do |format|
      format.html
      format.json do
        if @errors.any?
          render json: { errors: @errors }, status: :unprocessable_entity
        else
          render json: {
            logs: @logs.as_json(
              only: [ :id, :created_at, :level, :status, :http_status, :user_id, :message, :ip ],
              methods: (@query.present? ? [ :rank ] : [])
            ),
            page: @page,
            has_next: @has_next
          }
        end
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    @errors = [ "Something went wrong running that query (#{e.cause&.class&.name || e.class.name})." ]
    @logs = []
    @has_next = false
    respond_to do |format|
      format.html { render :index, status: :internal_server_error }
      format.json { render json: { errors: @errors }, status: :internal_server_error }
    end
  end

  private

  # Validate upfront rather than let bad input silently disappear into an
  # empty result set (was previously the case for, e.g., a malformed IP) or
  # crash on an invalid integer cast against a bigint/integer column.
  def validate_filters
    errors = []

    if @from.present? && (Date.parse(@from) rescue nil).nil?
      errors << "\"From\" is not a valid date."
    end
    if @to.present? && (Date.parse(@to) rescue nil).nil?
      errors << "\"To\" is not a valid date."
    end
    if @ip.present? && !Log.valid_ip_or_cidr?(@ip)
      errors << "\"#{@ip}\" is not a valid IP address or CIDR range."
    end
    if @user_id.present? && !Log.valid_integer?(@user_id)
      errors << "User ID must be a whole number."
    end
    if @http_status.present? && !Log.valid_integer?(@http_status)
      errors << "HTTP status must be a whole number."
    end

    errors
  end

  def run_query
    logs = Log.search(@query)
              .in_time_range(@from, @to)
              .with_ip(@ip)
              .with_status(@status)
              .with_level(@level)
              .with_user_id(@user_id)
              .with_http_status(@http_status)

    # Sorting by rank only makes sense while actively searching; otherwise
    # honor the whitelisted column/direction from the sort links.
    logs = logs.sorted_by(@sort, @dir) if @query.blank?

    # Fetch one extra row instead of a separate COUNT(*) to know whether a
    # "Next" page exists, without a second full scan of the filtered set.
    offset = (@page - 1) * PER_PAGE
    fetched = logs.offset(offset).limit(PER_PAGE + 1).to_a
    @has_next = fetched.size > PER_PAGE
    @logs = fetched.first(PER_PAGE)
  end
end
