require "faker"
require "json"
require "time"

# Generates realistic-ish random log events as plain Hashes.
class LogGenerator
  LEVELS = %w[debug info warn error].freeze

  # Weighted so most requests succeed — repeat values to bias .sample
  STATUSES = [200, 200, 200, 200, 301, 404, 500].freeze

  def initialize(user_pool: 1..1000)
    @user_pool = user_pool
  end

  def generate
    level = LEVELS.sample
    status = STATUSES.sample
    return {
      timestamp: Time.now - rand(0..7 * 24 * 60 * 60),
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

  def generate_many(count)
    Array.new(count) { generate }
  end
end

if __FILE__ == $PROGRAM_NAME
  generator = LogGenerator.new

  generator.generate_many(5).each do |log|
    puts log.to_json
  end
end
