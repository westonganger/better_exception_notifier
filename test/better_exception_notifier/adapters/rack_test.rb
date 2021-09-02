# require 'test_helper'

class RackTest < ActiveSupport::TestCase
  setup do
    @pass_app = Object.new
    @pass_app.stubs(:call).returns([nil, { 'X-Cascade' => 'pass' }, nil])

    @normal_app = Object.new
    @normal_app.stubs(:call).returns([nil, {}, nil])
  end

  teardown do
    BetterExceptionNotifier.reset_notifiers!
  end

  test 'should ignore "X-Cascade" header by default' do
    BetterExceptionNotifier.expects(:notify_exception).never
    BetterExceptionNotifier::Rack.new(@pass_app).call({})
  end

  test 'should notify on "X-Cascade" = "pass" if ignore_cascade_pass option is false' do
    BetterExceptionNotifier.expects(:notify_exception).once
    BetterExceptionNotifier::Rack.new(@pass_app, ignore_cascade_pass: false).call({})
  end

  test 'should ignore exceptions if ignore_if condition is met' do
    exception_app = Object.new
    exception_app.stubs(:call).raises(RuntimeError)

    env = {}

    begin
      BetterExceptionNotifier::Rack.new(
        exception_app,
        ignore_if: ->(_env, exception) { exception.is_a? RuntimeError }
      ).call(env)

      flunk
    rescue StandardError
      refute env['better_exception_notifier.delivered']
    end
  end

  test 'should ignore exceptions with notifiers that satisfies ignore_notifier_if condition' do
    exception_app = Object.new
    exception_app.stubs(:call).raises(RuntimeError)

    notifier1_called = notifier2_called = false
    notifier1 = ->(_exception, _options) { notifier1_called = true }
    notifier2 = ->(_exception, _options) { notifier2_called = true }

    env = {}

    begin
      BetterExceptionNotifier::Rack.new(
        exception_app,
        ignore_notifier_if: {
          notifier1: ->(_env, exception) { exception.is_a? RuntimeError }
        },
        notifier1: notifier1,
        notifier2: notifier2
      ).call(env)

      flunk
    rescue StandardError
      refute notifier1_called
      assert notifier2_called
    end
  end
end
