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
    @sort = params[:sort]
    @dir = params[:dir]
    @page = [params[:page].to_i, 1].max

    logs = Log.search(@query)
              .in_time_range(@from, @to)
              .with_ip(@ip)
              .with_status(@status)
              .with_level(@level)
              .with_user_id(@user_id)

    # Sorting by rank only makes sense while actively searching; otherwise
    # honor the whitelisted column/direction from the sort links.
    logs = logs.sorted_by(@sort, @dir) if @query.blank?

    # Fetch one extra row instead of a separate COUNT(*) to know whether a
    # "Next" page exists, without a second full scan of the filtered set.
    offset = (@page - 1) * PER_PAGE
    fetched = logs.offset(offset).limit(PER_PAGE + 1).to_a
    @has_next = fetched.size > PER_PAGE
    @logs = fetched.first(PER_PAGE)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          logs: @logs.as_json(
            only: [:id, :created_at, :level, :status, :http_status, :user_id, :message, :ip],
            methods: (@query.present? ? [:rank] : [])
          ),
          page: @page,
          has_next: @has_next
        }
      end
    end
  end
end
