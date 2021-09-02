# require 'better_exception_notifier'
require 'better_exception_notifier/rack'
require 'better_exception_notifier/version'

# require 'logger'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/module/attribute_accessors'
require 'better_exception_notifier/base_notifier'

module BetterExceptionNotifier
  autoload :BacktraceCleaner, 'better_exception_notifier/modules/backtrace_cleaner'
  autoload :Formatter, 'better_exception_notifier/modules/formatter'

  autoload :Notifier, 'better_exception_notifier/notifier'
  autoload :EmailNotifier, 'better_exception_notifier/email_notifier'
  autoload :CampfireNotifier, 'better_exception_notifier/campfire_notifier'
  autoload :HipchatNotifier, 'better_exception_notifier/hipchat_notifier'
  autoload :WebhookNotifier, 'better_exception_notifier/webhook_notifier'
  autoload :IrcNotifier, 'better_exception_notifier/irc_notifier'
  autoload :SlackNotifier, 'better_exception_notifier/slack_notifier'
  autoload :MattermostNotifier, 'better_exception_notifier/mattermost_notifier'
  autoload :TeamsNotifier, 'better_exception_notifier/teams_notifier'
  autoload :SnsNotifier, 'better_exception_notifier/sns_notifier'
  autoload :GoogleChatNotifier, 'better_exception_notifier/google_chat_notifier'
  autoload :DatadogNotifier, 'better_exception_notifier/datadog_notifier'

  class UndefinedNotifierError < StandardError; end

  # Define logger
  mattr_accessor :logger
  @@logger = Logger.new(STDOUT)

  # Define a set of exceptions to be ignored, ie, dont send notifications when any of them are raised.
  mattr_accessor :ignored_exceptions
  @@ignored_exceptions = []

  mattr_accessor :testing_mode
  @@testing_mode = false

  # Store conditions that decide when exceptions must be ignored or not.
  @@ignores = []

  # Store by-notifier conditions that decide when exceptions must be ignored or not.
  @@by_notifier_ignores = {}

  # Store notifiers that send notifications when exceptions are raised.
  @@notifiers = {}

  # Alternative way to setup BetterExceptionNotifier.
  # Run 'rails generate better_exception_notifier:install' to create
  # a fresh initializer with all configuration values.
  def self.configure
    yield BetterExceptionNotifier
  end

  def self.testing_mode!
    self.testing_mode = true
  end

  def self.notify_exception(exception, options = {}, &block)
    if ignored_exception?(options[:ignore_exceptions], exception) || ignored?(exception, options)
      return false
    end

    notification_fired = false

    selected_notifiers = options.delete(:notifiers) || notifiers

    [*selected_notifiers].each do |notifier|
      if !notifier_ignored?(exception, options, notifier: notifier)
        fire_notification(notifier, exception, options.dup, &block)
        notification_fired = true
      end
    end

    notification_fired
  end

  def self.register_better_exception_notifier(name, notifier_or_options)
    if notifier_or_options.respond_to?(:call)
      @@notifiers[name] = notifier_or_options
    elsif notifier_or_options.is_a?(Hash)
      create_and_register_notifier(name, notifier_or_options)
    else
      raise ArgumentError, "Invalid notifier '#{name}' defined as #{notifier_or_options.inspect}"
    end
  end
  alias add_notifier register_better_exception_notifier

  def self.unregister_better_exception_notifier(name)
    @@notifiers.delete(name)
  end

  def self.registered_better_exception_notifier(name)
    @@notifiers[name]
  end

  def self.notifiers
    @@notifiers.keys
  end

  # Adds a condition to decide when an exception must be ignored or not.
  #
  #   BetterExceptionNotifier.ignore_if do |exception, options|
  #     not Rails.env.production?
  #   end
  def self.ignore_if(&block)
    @@ignores << block
  end

  def self.ignore_notifier_if(notifier, &block)
    @@by_notifier_ignores[notifier] = block
  end

  def self.clear_ignore_conditions!
    @@ignores.clear

    @@by_notifier_ignores.clear
  end

  def self.reset_notifiers!
    @@notifiers = {}
    clear_ignore_conditions!
  end

  private

  def self.ignored?(exception, options)
    @@ignores.any? { |condition| condition.call(exception, options) }
  rescue Exception => e
    if @@testing_mode
      raise e 
    end

    logger.warn("An error occurred when evaluating an ignore condition. #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")

    false
  end

  def self.notifier_ignored?(exception, options, notifier:)
    if !@@by_notifier_ignores.key?(notifier)
      return false
    end

    condition = @@by_notifier_ignores[notifier]

    condition.call(exception, options)
  rescue Exception => e
    if @@testing_mode
      raise e
    end

    msg = <<~"MESSAGE"
      An error occurred when evaluating a by-notifier ignore condition. #{e.class}: #{e.message}
      #{e.backtrace.join("\n")}
    MESSAGE

    logger.warn(msg)

    false
  end

  def self.ignored_exception?(ignore_array, exception)
    all_ignored_exceptions = (Array(ignored_exceptions) + Array(ignore_array)).map(&:to_s)

    exception_ancestors = exception.singleton_class.ancestors.map(&:to_s)

    !(all_ignored_exceptions & exception_ancestors).empty?
  end

  def self.fire_notification(notifier_name, exception, options, &block)
    notifier = registered_better_exception_notifier(notifier_name)

    notifier.call(exception, options, &block)
  rescue Exception => e
    if @@testing_mode
      raise e
    end

    logger.warn(
      "An error occurred when sending a notification using '#{notifier_name}' notifier." \
      "#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
    )

    false
  end

  def self.create_and_register_notifier(name, options)
    notifier_classname = "#{name}_notifier".camelize
    notifier_class = BetterExceptionNotifier.const_get(notifier_classname)
    notifier = notifier_class.new(options)
    register_better_exception_notifier(name, notifier)
  rescue NameError => e
    raise UndefinedNotifierError.new("No notifier named '#{name}' was found. Please, revise your configuration options. Cause: #{e.message}")
  end
end
