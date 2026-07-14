require_relative "../../log_generator"

namespace :logs do
  desc "Seed the logs table with randomly generated log events (create, one row at a time)"
  task :seed, [:count] => :environment do |_task, args|
    count = (args[:count] || 1000).to_i
    start_time = Time.now

    puts "Seeding #{count} logs..." 

    status_map = {
      200 => 'ok', 
      301 => 'ok', 
      404 => 'client_error', 
      500 => 'server_error'
    }

    log_generator = LogGenerator.new

    log_generator.generate_many(count).each do |log|
      Log.create!({
        created_at: log[:timestamp],
        http_status: log[:status],
        status: status_map[log[:status]],
        level: log[:level],
        ip: log[:metadata][:ip],
        message: log[:message],
        metadata: log[:metadata],
        user_id: log[:user_id]
      })
    end

    puts "done in #{Time.now - start_time}s"
  end

  desc "Seed the logs table with randomly generated log events (insert_all, batched)"
  task :seed_bulk, [:count] => :environment do |_task, args|
    count = (args[:count] || 1000).to_i
    batch_size = 1000

    start_time = Time.now
    puts "Seeding #{count} logs in batches of #{batch_size}..."

    status_map = {
      200 => 'ok',
      301 => 'ok',
      404 => 'client_error',
      500 => 'server_error'
    }

    log_generator = LogGenerator.new

    count.step(0, -batch_size) do |remaining|
      break if remaining <= 0

      batch = log_generator.generate_many([remaining, batch_size].min).map do |log|
        {
          created_at: log[:timestamp],
          http_status: log[:status],
          status: status_map[log[:status]],
          level: log[:level],
          ip: log[:metadata][:ip],
          message: log[:message],
          metadata: log[:metadata],
          user_id: log[:user_id]
        }
      end

      Log.insert_all(batch, record_timestamps: false)
    end

    puts "done in #{Time.now - start_time}s"
  end
end
