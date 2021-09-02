$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'better_exception_notifier'

require 'minitest/autorun'
require 'mocha/minitest'
require 'active_support/test_case'
require 'action_mailer'

BetterExceptionNotifier.testing_mode!

Time.zone = 'UTC'
ActionMailer::Base.delivery_method = :test
ActionMailer::Base.append_view_path("#{File.dirname(__FILE__)}/support/views")
