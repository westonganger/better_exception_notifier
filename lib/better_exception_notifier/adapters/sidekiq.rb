# require 'sidekiq'

if Sidekiq::VERSION.to_f >= 3

  Sidekiq.configure_server do |config|
    handler = ->(ex, content){
      BetterExceptionNotifier.notify_exception(ex, data: { sidekiq: context })
    }

    config.error_handlers << handler
  end

else
  ### Sidekiq < v3

  module BetterExceptionNotifier
    class Sidekiq
      def call(_worker, msg, _queue)
        yield
      rescue Exception => e
        BetterExceptionNotifier.notify_exception(e, data: { sidekiq: msg })
        raise e
      end
    end
  end

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add ::BetterExceptionNotifierSidekiq
    end
  end

end
