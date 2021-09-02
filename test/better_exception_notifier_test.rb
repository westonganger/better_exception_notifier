# require 'test_helper'

class ExceptionOne < StandardError; end
class ExceptionTwo < StandardError; end

class BetterExceptionNotifierTest < ActiveSupport::TestCase
  setup do
    BetterExceptionNotifier.register_better_exception_notifier(:email, exception_recipients: %w[dummyexceptions@example.com])

    @notifier_calls = 0
    @test_notifier = ->(_exception, _options) { @notifier_calls += 1 }
  end

  teardown do
    BetterExceptionNotifier.reset_notifiers!

    Rails.cache.clear if defined?(Rails) && Rails.respond_to?(:cache)
  end

  test 'should not have any default ignored exceptions' do
    assert_equal BetterExceptionNotifier.ignored_exceptions, []
  end

  test 'should have email notifier registered' do
    assert_equal BetterExceptionNotifier.notifiers, [:email]
  end

  test 'should have a valid email notifier' do
    @email_notifier = BetterExceptionNotifier.registered_better_exception_notifier(:email)
    refute_nil @email_notifier
    assert_equal @email_notifier.class, BetterExceptionNotifier::EmailNotifier
    assert_respond_to @email_notifier, :call
  end

  test 'should allow register/unregister another notifier' do
    called = false
    proc_notifier = ->(_exception, _options) { called = true }
    BetterExceptionNotifier.register_better_exception_notifier(:proc, proc_notifier)

    assert_equal BetterExceptionNotifier.notifiers.sort, %i[email proc]

    exception = StandardError.new

    BetterExceptionNotifier.notify_exception(exception)
    assert called

    BetterExceptionNotifier.unregister_better_exception_notifier(:proc)
    assert_equal BetterExceptionNotifier.notifiers, [:email]
  end

  test 'should allow select notifiers to send error to' do
    notifier1_calls = 0
    notifier1 = ->(_exception, _options) { notifier1_calls += 1 }
    BetterExceptionNotifier.register_better_exception_notifier(:notifier1, notifier1)

    notifier2_calls = 0
    notifier2 = ->(_exception, _options) { notifier2_calls += 1 }
    BetterExceptionNotifier.register_better_exception_notifier(:notifier2, notifier2)

    assert_equal BetterExceptionNotifier.notifiers.sort, %i[email notifier1 notifier2]

    exception = StandardError.new
    BetterExceptionNotifier.notify_exception(exception)
    assert_equal notifier1_calls, 1
    assert_equal notifier2_calls, 1

    BetterExceptionNotifier.notify_exception(exception, notifiers: :notifier1)
    assert_equal notifier1_calls, 2
    assert_equal notifier2_calls, 1

    BetterExceptionNotifier.notify_exception(exception, notifiers: :notifier2)
    assert_equal notifier1_calls, 2
    assert_equal notifier2_calls, 2

    BetterExceptionNotifier.unregister_better_exception_notifier(:notifier1)
    BetterExceptionNotifier.unregister_better_exception_notifier(:notifier2)
    assert_equal BetterExceptionNotifier.notifiers, [:email]
  end

  test 'should ignore exception if satisfies conditional ignore' do
    env = 'production'
    BetterExceptionNotifier.ignore_if do |_exception, _options|
      env != 'production'
    end

    BetterExceptionNotifier.register_better_exception_notifier(:test, @test_notifier)

    exception = StandardError.new

    BetterExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1

    env = 'development'
    BetterExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1
  end

  test 'should ignore exception if satisfies by-notifier conditional ignore' do
    notifier1_calls = 0
    notifier1 = ->(_exception, _options) { notifier1_calls += 1 }
    BetterExceptionNotifier.register_better_exception_notifier(:notifier1, notifier1)

    notifier2_calls = 0
    notifier2 = ->(_exception, _options) { notifier2_calls += 1 }
    BetterExceptionNotifier.register_better_exception_notifier(:notifier2, notifier2)

    env = 'production'
    BetterExceptionNotifier.ignore_notifier_if(:notifier1) do |_exception, _options|
      env == 'development'
    end
    BetterExceptionNotifier.ignore_notifier_if(:notifier2) do |_exception, _options|
      env == 'production'
    end

    exception = StandardError.new

    BetterExceptionNotifier.notify_exception(exception)
    assert_equal notifier1_calls, 1
    assert_equal notifier2_calls, 0

    env = 'development'

    BetterExceptionNotifier.notify_exception(exception)
    assert_equal notifier1_calls, 1
    assert_equal notifier2_calls, 1

    env = 'test'

    BetterExceptionNotifier.notify_exception(exception)
    assert_equal notifier1_calls, 2
    assert_equal notifier2_calls, 2
  end

  test 'should return false if all the registered notifiers are ignored' do
    BetterExceptionNotifier.notifiers.each do |notifier|
      # make sure to register no other notifiers but the tested ones
      BetterExceptionNotifier.unregister_better_exception_notifier(notifier)
    end

    BetterExceptionNotifier.register_better_exception_notifier(:notifier1, ->(_, _) {})
    BetterExceptionNotifier.register_better_exception_notifier(:notifier2, ->(_, _) {})

    BetterExceptionNotifier.ignore_notifier_if(:notifier1) do |exception, _options|
      exception.message =~ /non_critical_error/
    end
    BetterExceptionNotifier.ignore_notifier_if(:notifier2) do |exception, _options|
      exception.message =~ /non_critical_error/
    end

    exception = StandardError.new('a non_critical_error occured.')

    refute BetterExceptionNotifier.notify_exception(exception)
  end

  test 'should return true if one of the notifiers fires' do
    BetterExceptionNotifier.notifiers.each do |notifier|
      # make sure to register no other notifiers but the tested ones
      BetterExceptionNotifier.unregister_better_exception_notifier(notifier)
    end

    BetterExceptionNotifier.register_better_exception_notifier(:notifier1, ->(_, _) {})
    BetterExceptionNotifier.register_better_exception_notifier(:notifier2, ->(_, _) {})

    BetterExceptionNotifier.ignore_notifier_if(:notifier1) do |exception, _options|
      exception.message =~ /non-critical\serror/
    end

    exception = StandardError.new('a non-critical error occured')

    assert BetterExceptionNotifier.notify_exception(exception)
  end

  test 'should not send notification if one of ignored exceptions' do
    BetterExceptionNotifier.register_better_exception_notifier(:test, @test_notifier)

    exception = StandardError.new

    BetterExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1

    BetterExceptionNotifier.notify_exception(exception, notifiers: :test, ignore_exceptions: 'StandardError')
    assert_equal @notifier_calls, 1
  end

  test 'should not send notification if subclass of one of ignored exceptions' do
    BetterExceptionNotifier.register_better_exception_notifier(:test, @test_notifier)

    class StandardErrorSubclass < StandardError
    end

    exception = StandardErrorSubclass.new

    BetterExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1

    BetterExceptionNotifier.notify_exception(exception, notifiers: :test, ignore_exceptions: 'StandardError')
    assert_equal @notifier_calls, 1
  end

  test 'should not send notification if extended module one of ignored exceptions' do
    BetterExceptionNotifier.register_better_exception_notifier(:test, @test_notifier)

    module StandardErrorModule; end

    exception = StandardError.new
    exception.extend StandardErrorModule

    BetterExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1

    ignore_exceptions = 'BetterExceptionNotifierTest::StandardErrorModule'
    BetterExceptionNotifier.notify_exception(exception, notifiers: :test, ignore_exceptions: ignore_exceptions)
    assert_equal @notifier_calls, 1
  end

  test 'should not send notification if prepended module at singleton class one of ignored exceptions' do
    BetterExceptionNotifier.register_better_exception_notifier(:test, @test_notifier)

    module StandardErrorModule; end

    exception = StandardError.new
    exception.singleton_class.prepend StandardErrorModule

    BetterExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1

    ignore_exceptions = 'BetterExceptionNotifierTest::StandardErrorModule'
    BetterExceptionNotifier.notify_exception(exception, notifiers: :test, ignore_exceptions: ignore_exceptions)
    assert_equal @notifier_calls, 1
  end

  test 'should call received block' do
    @block_called = false
    notifier = ->(_exception, _options, &block) { block.call }
    BetterExceptionNotifier.register_better_exception_notifier(:test, notifier)

    exception = ExceptionOne.new

    BetterExceptionNotifier.notify_exception(exception) do
      @block_called = true
    end

    assert @block_called
  end

  test 'should skip notification if send_notification? is false' do
    exception = StandardError.new
    BetterExceptionNotifier.expects(:send_notification?).with(exception, 1).once.returns(false)

    refute BetterExceptionNotifier.notify_exception(exception)
  end

  test 'should send notification if send_notification? is true' do
    exception = StandardError.new
    BetterExceptionNotifier.expects(:send_notification?).with(exception, 1).once.returns(true)

    assert BetterExceptionNotifier.notify_exception(exception)
  end
end
