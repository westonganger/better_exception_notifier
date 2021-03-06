module BetterExceptionNotifier
  class BaseNotifier

    attr_accessor :base_options

    def initialize(options = {})
      @base_options = options
    end

    def send_notice(exception, options, message, message_opts = nil)
      _pre_callback(exception, options, message, message_opts)
      result = yield(message, message_opts)
      _post_callback(exception, options, message, message_opts)
      result
    end

    def _pre_callback(exception, options, message, message_opts)
      return unless @base_options[:pre_callback].respond_to?(:call)

      @base_options[:pre_callback].call(options, self, exception.backtrace, message, message_opts)
    end

    def _post_callback(exception, options, message, message_opts)
      return unless @base_options[:post_callback].respond_to?(:call)

      @base_options[:post_callback].call(options, self, exception.backtrace, message, message_opts)
    end

    def clean_backtrace(exception)
      if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        Rails.backtrace_cleaner.send(:filter, exception.backtrace)
      else
        exception.backtrace
      end
    end

  end
end
