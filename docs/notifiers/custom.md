### Custom notifier

Simply put, notifiers are objects which respond to `#call(exception, options)` method. Thus, a lambda can be used as a notifier as follow:

```ruby
BetterExceptionNotifier.add_notifier :custom_notifier_name,
  ->(exception, options) { puts "Something goes wrong: #{exception.message}"}
```

More advanced users or third-party framework developers, also can create notifiers to be shipped in gems and take advantage of BetterExceptionNotifier's Notifier API to standardize the [various](https://github.com/airbrake/airbrake) [solutions](https://www.honeybadger.io) [out](http://www.exceptional.io) [there](https://bugsnag.com). For this, beyond the `#call(exception, options)` method, the notifier class MUST BE defined under the BetterExceptionNotifier namespace and its name sufixed by `Notifier`, e.g: BetterExceptionNotifier::CustomNotifier.

#### Example

Define the custom notifier:

```ruby
module BetterExceptionNotifier
  class CustomNotifier
    def initialize(options)
      # do something with the options...
    end

    def call(exception, options={})
      # send the notification
    end
  end
end
```

Using it:

```ruby
Rails.application.config.middleware.use BetterExceptionNotifier::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        simple: {
                                          # simple notifier options
                                        }
```
