module BetterExceptionNotifier
  class Engine < ::Rails::Engine
    config.better_exception_notifier = BetterExceptionNotifier
    config.better_exception_notifier.logger = Rails.logger

    config.app_middleware.use BetterExceptionNotifier::Rack
  end
end
