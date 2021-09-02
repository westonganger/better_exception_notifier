module BetterExceptionNotifier
  class Rack
    class CascadePassException < RuntimeError; end

    def initialize(app, options = {})
      @app = app

      BetterExceptionNotifier.tap do |en|
        if options.key?(:ignore_exceptions)
          en.ignored_exceptions = options.delete(:ignore_exceptions)
        end
      end

      if options.key?(:ignore_if)
        rack_ignore = options.delete(:ignore_if)

        BetterExceptionNotifier.ignore_if do |exception, opts|
          opts.key?(:env) && rack_ignore.call(opts[:env], exception)
        end
      end

      if options.key?(:ignore_notifier_if)
        rack_ignore_by_notifier = options.delete(:ignore_notifier_if)

        rack_ignore_by_notifier.each do |notifier, the_proc|
          BetterExceptionNotifier.ignore_notifier_if(notifier) do |exception, opts|
            opts.key?(:env) && the_proc.call(opts[:env], exception)
          end
        end
      end

      @ignore_cascade_pass = options.delete(:ignore_cascade_pass) { true }

      options.each do |notifier_name, opts|
        BetterExceptionNotifier.register_better_exception_notifier(notifier_name, opts)
      end
    end

    def call(env)
      _, headers, = response = @app.call(env)

      if !@ignore_cascade_pass && headers['X-Cascade'] == 'pass'
        msg = "This exception means that the preceding Rack middleware set the 'X-Cascade' header to 'pass' -- in Rails, this often means that the route was not found (404 error).'
        raise CascadePassException, msg
      end

      response
    rescue Exception => e
      if BetterExceptionNotifier.notify_exception(e, env: env)
        env['better_exception_notifier.delivered'] = true
      end

      if !e.is_a?(CascadePassException)
        raise e
      end

      response
    end
  end
end
