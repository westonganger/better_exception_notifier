# require 'test_helper'

# To allow sidekiq error handlers to be registered, sidekiq must be in
# "server mode". This mode is triggered by loading sidekiq/cli. Note this
# has to be loaded before better_exception_notifier/sidekiq.
require 'sidekiq/cli'
require 'sidekiq/testing'

require 'better_exception_notifier/sidekiq'

class MockSidekiqServer
  include ::Sidekiq::ExceptionHandler
end

class SidekiqTest < ActiveSupport::TestCase
  test 'should call notify_exception when sidekiq raises an error' do
    server = MockSidekiqServer.new
    message = {}
    exception = RuntimeError.new

    BetterExceptionNotifier.expects(:notify_exception).with(
      exception,
      data: { sidekiq: message }
    )

    server.handle_exception(exception, message)
  end
end
