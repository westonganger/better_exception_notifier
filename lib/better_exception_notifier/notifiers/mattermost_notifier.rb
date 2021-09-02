# require 'httparty'

module BetterExceptionNotifier
  class MattermostNotifier < BaseNotifier
    def call(exception, opts = {})
      options = opts.merge(base_options)
      @exception = exception

      @formatter = self.class::Formatter.new(exception, options)

      @gitlab_url = options[:git_url]

      @env = options[:env] || {}

      payload = {
        text: message_text.compact.join("\n"),
        username: options[:username] || 'Exception Notifier'
      }

      payload[:icon_url] = options[:avatar] if options[:avatar]
      payload[:channel] = options[:channel] if options[:channel]

      httparty_options = options.except(
        :avatar, :channel, :username, :git_url, :webhook_url,
        :env, :accumulated_errors_count, :app_name
      )

      httparty_options[:body] = payload.to_json
      httparty_options[:headers] ||= {}
      httparty_options[:headers]['Content-Type'] = 'application/json'

      HTTParty.post(options[:webhook_url], httparty_options)
    end

    private

    def message_text
      text = [
        '@channel',
        "### #{@formatter.title}",
        @formatter.subtitle,
        "*#{@exception.message}*"
      ]

      if (request = @formatter.request_message.presence)
        text << '### Request'
        text << request
      end

      if (backtrace = @formatter.backtrace_message.presence)
        text << '### Backtrace'
        text << backtrace
      end

      if (exception_data = @env['better_exception_notifier.exception_data'])
        text << '### Data'
        data_string = exception_data.map { |k, v| "* #{k} : #{v}" }.join("\n")
        text << "```\n#{data_string}\n```"
      end

      text << message_issue_link if @gitlab_url

      text
    end

    def message_issue_link
      link = [@gitlab_url, @formatter.app_name, 'issues', 'new'].join('/')
      params = {
        'issue[title]' => ['[BUG] Error 500 :',
                           @formatter.controller_and_action || '',
                           "(#{@exception.class})",
                           @exception.message].compact.join(' ')
      }.to_query

      "[Create an issue](#{link}/?#{params})"
    end


    class Formatter

      attr_reader :app_name

      def initialize(exception, opts = {})
        @exception = exception

        @env = opts[:env]
        @errors_count = opts[:accumulated_errors_count].to_i
        @app_name = opts[:app_name] || rails_app_name
      end

      #
      # :warning: Error occurred in production :warning:
      # :warning: Error occurred :warning:
      #
      def title
        env = Rails.env if defined?(::Rails) && ::Rails.respond_to?(:env)

        if env
          "⚠️ Error occurred in #{env} ⚠️"
        else
          '⚠️ Error occurred ⚠️'
        end
      end

      #
      # A *NoMethodError* occurred.
      # 3 *NoMethodError* occurred.
      # A *NoMethodError* occurred in *home#index*.
      #
      def subtitle
        errors_text = if errors_count > 1
                        errors_count
                      else
                        exception.class.to_s =~ /^[aeiou]/i ? 'An' : 'A'
                      end

        in_action = " in *#{controller_and_action}*" if controller

        "#{errors_text} *#{exception.class}* occurred#{in_action}."
      end

      #
      #
      # *Request:*
      # ```
      # * url : https://www.example.com/
      # * http_method : GET
      # * ip_address : 127.0.0.1
      # * parameters : {"controller"=>"home", "action"=>"index"}
      # * timestamp : 2019-01-01 00:00:00 UTC
      # ```
      #
      def request_message
        request = ActionDispatch::Request.new(env) if env
        return unless request

        [
          '```',
          "* url : #{request.original_url}",
          "* http_method : #{request.method}",
          "* ip_address : #{request.remote_ip}",
          "* parameters : #{request.filtered_parameters}",
          "* timestamp : #{Time.current}",
          '```'
        ].join("\n")
      end

      #
      #
      # *Backtrace:*
      # ```
      # * app/controllers/my_controller.rb:99:in `specific_function'
      # * app/controllers/my_controller.rb:70:in `specific_param'
      # * app/controllers/my_controller.rb:53:in `my_controller_params'
      # ```
      #
      def backtrace_message
        backtrace = exception.backtrace ? clean_backtrace(exception) : nil

        return unless backtrace

        text = []

        text << '```'
        backtrace.first(3).each { |line| text << "* #{line}" }
        text << '```'

        text.join("\n")
      end

      #
      # home#index
      #
      def controller_and_action
        if controller
          "#{controller.controller_name}##{controller.action_name}" 
        end
      end

      private

      attr_reader :exception, :env, :errors_count

      def rails_app_name
        unless defined?(::Rails) && ::Rails.respond_to?(:application)
          return
        end
        
        if Rails::VERSION::MAJOR >= 6
          Rails.application.class.module_parent_name.underscore
        else
          Rails.application.class.parent_name.underscore
        end
      end

      def controller
        if env
          env['action_controller.instance']
        end
      end

    end

  end
end
