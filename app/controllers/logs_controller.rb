class LogsController < ApplicationController
  def index
    @query = params[:q]
    @from = params[:from]
    @to = params[:to]
    @ip = params[:ip]
    @errors_only = params[:errors_only]

    @logs = Log.search(@query)
               .in_time_range(@from, @to)
               .with_ip(@ip)
               .server_errors_only(@errors_only)
               .limit(50)

    respond_to do |format|
      format.html
      format.json do
        render json: @logs.as_json(
          only: [:id, :created_at, :level, :status, :http_status, :user_id, :message, :ip],
          methods: (@query.present? ? [:rank] : [])
        )
      end
    end
  end
end
