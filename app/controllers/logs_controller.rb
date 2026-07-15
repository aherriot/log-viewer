class LogsController < ApplicationController
  def index
    @query = params[:q]
    @from = params[:from]
    @to = params[:to]
    @ip = params[:ip]

    @logs = Log.search(@query)
               .in_time_range(@from, @to)
               .with_ip(@ip)
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
