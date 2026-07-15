require "faker"
require "json"
require "time"

# Generates realistic-ish random log events as plain Hashes.
class LogGenerator
  LEVELS = %w[debug info warn error].freeze

  # Weighted so most requests succeed — repeat values to bias .sample
  STATUSES = [ 200, 200, 200, 200, 301, 404, 500 ].freeze

  def initialize(user_pool: 1..1000, start_time: Time.now - 7 * 24 * 60 * 60)
    @user_pool = user_pool
    @clock = start_time
  end

  def generate
    level = LEVELS.sample
    status = STATUSES.sample
    {
      timestamp: @clock,
      level: level,
      status: status,
      user_id: rand(@user_pool),
      message: "#{level.upcase} #{status} - #{Faker::Lorem.sentence}",
      metadata: {
        ip: Faker::Internet.ip_v4_address,
        browser:  Faker::Internet.user_agent,
        endpoint: "/" + Faker::Internet.slug(glue: "/")
      }
    }
  end

  # Advances an internal clock forward by a small, jittered step per row,
  # instead of picking each timestamp independently at random. This keeps
  # generation order and created_at order correlated (as in a real log
  # stream), which BRIN indexes rely on. `span` controls how much wall-clock
  # time the whole batch covers, defaulting to one hour.
  def generate_many(count, span: 60 * 60)
    average_step = count.positive? ? span.to_f / count : 0

    Array.new(count) do
      event = generate
      @clock += rand(0.0..(average_step * 2))
      event
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  generator = LogGenerator.new

  generator.generate_many(5).each do |log|
    puts log.to_json
  end
end
