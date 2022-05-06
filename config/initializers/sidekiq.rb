Sidekiq.configure_server do |config|
  url = Rails.env.production? ? ENV.fetch('REDIS_URL') : 'redis://localhost:6379'
  config.redis = { url: url, namespace: 'touhou_karaoke_sidekiq' }
end

Sidekiq.configure_client do |config|
  url = Rails.env.production? ? ENV.fetch('REDIS_URL') : 'redis://localhost:6379'
  config.redis = { url: url, namespace: 'touhou_karaoke_sidekiq' }
end

Sidekiq::DelayExtensions.enable_delay!
