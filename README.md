# BetterExceptionNotifier

<a href="https://badge.fury.io/rb/better_exception_notifier" target="_blank"><img height="21" style='border:0px;height:21px;' border='0' src="https://badge.fury.io/rb/better_exception_notifier.svg" alt="Gem Version"></a>
<a href='https://github.com/westonganger/better_exception_notifier/actions' target='_blank'><img src="https://github.com/westonganger/better_exception_notifier/workflows/Tests/badge.svg" style="max-width:100%;" height='21' style='border:0px;height:21px;' border='0' alt="CI Status"></a>
<a href='https://rubygems.org/gems/better_exception_notifier' target='_blank'><img height='21' style='border:0px;height:21px;' src='https://ruby-gem-downloads-badge.herokuapp.com/better_exception_notifier?label=rubygems&type=total&total_label=downloads&color=brightgreen' border='0' alt='RubyGems Downloads' /></a>

Easy-to-use exception notifier for Rails and Rack applications.

Key Features:

- 1
- 2
- 3

# Notifiers

Most common Notifiers:

* [Email notifier](docs/notifiers/email.md)
* [WebHook notifier](docs/notifiers/webhook.md)
* [IRC notifier](docs/notifiers/irc.md)
* [Slack notifier](docs/notifiers/slack.md)
* [Custom Notifiers](docs/notifiers/custom.md)

Other Notifiers:

* [Amazon SNS](docs/notifiers/sns.md)
* [Campfire notifier](docs/notifiers/campfire.md)
* [Datadog notifier](docs/notifiers/datadog.md)
* [Google Chat notifier](docs/notifiers/google_chat.md)
* [HipChat notifier](docs/notifiers/hipchat.md)
* [Mattermost notifier](docs/notifiers/mattermost.md)
* [Teams notifier](docs/notifiers/teams.md)

Custom notifiers can be created easily. See documentation for [custom notifiers](docs/notifiers/custom.md).

# Installation

Add the following line to your application's Gemfile:

```ruby
gem 'better_exception_notifier'
```

### Rails

Add the following config file to your initializers

```ruby
### config/initializers/better_exception_notifier.rb

BetterExceptionNotifier.configure do |config|
  config.ignored_exceptions = [
    AbstractController::ActionNotFound, 
    ActionController::RoutingError,
  ]

  config.send_if = ->(){ true },
  # OR
  #config.ignore_if = ->(){ false },
  #config.skip_if = ->(){ false },
  config.skip_notifier_when = ->(notifier_name){ false },

  config.email = {
    deliver_with: :deliver, # Rails >= 4.2.1 do not need this option since it defaults to :deliver_now
    email_prefix: "[EXCEPTION #{APP_NAME}] ",
    sender_address: %{ "notifier" <notifier@example.com> }.strip,
    exception_recipients: ["admin@example.com"],
  }
end

Rails.application.config.middleware.use(BetterExceptionNotifier::Rails)
```

### Any Rack framework (Rack::App, Sinatra, etc.)

```ruby
class MyApp < Rack::App

  BetterExceptionNotifier.configure do |config|
    # ...
  end

  use BetterExceptionNotifier::Rack

end

# Manually notify of exception

```ruby
BetterExceptionNotifier.notify_exception(exception, env: request.env, data: {
  message: "someting wong",
)}
```

# How to set custom data to be included alongside the exception details

```ruby
class ApplicationController < ActionController::Base
  before_action :set_better_exception_notifier_data

  private

  def set_better_exception_notifier_data
    request.env["better_exception_notifier.data"] = {
      current_user: current_user
    }
  end
end
```

# Usage with Custom Exception Handling for Controllers

If your application controller handles exceptions, then the notifier will never be run. To manually notify of an error you can do something like the following:

```ruby
class ApplicationController < ActionController::Base

  rescue_from Exception do |exception|
    if should_send_notifications?
      BetterExceptionNotifier.notify_exception(exception, env: request.env, data: {
        message: "someting wong",
      })
    end
  end

  def should_send_notification?
    if Rails.env.development?
      ### Must skip in development because the exception will be re-raised so better_errors, etc can catch it
      return false
    end

    if !current_user && !request.referrer
      ### Handle Bots which wont set a referrer probably
      return false
    end

    case exception.class.name
    when AbstractController::ActionNotFound.name, ActionController::RoutingError.name
      return false
    when ActionController::BadRequest.name
      if exception.message.start_with?('Invalid query parameters: expected ')
        ### Usually caused by a bot
        return false
      elsif exception.message.start_with?('Invalid path parameters: Invalid encoding')
        ### Usually caused by a bot
        return false
      end
    end

    return true
  end

end
```

## Notifications in Background Jobs

In general to send notifications from background processes like Sidekiq or others, you can use the `notify_exception` method like this:

```ruby
begin
  some code...
rescue Exception => exception
  BetterExceptionNotifier.notify_exception(exception, data: {})
end
```

We have custom middleware for sidekiq if you use it:

Sidekiq Middleware - Source: [./lib/better_exception_notifier/sidekiq.rb]
```
require 'better_exception_notifier/sidekiq'
```

## Ignoring Certain Exceptions

### :ignore_exceptions

Ignore specified exception types. To achieve that, you should use the `:ignore_exceptions` option, like this:

```ruby
config.ignore_exceptions = [ActionView::TemplateError]
```

### :ignore_if

*Lambda, default: nil*

```ruby
config.ignore_if = ->(exception, env, data) { 
  exception.message.include?("Couldn't find Page with ID")
}
```

### :ignore_notifier_if

* Hash of Lambda, default: nil*

```ruby
config.ignore_notifier_if = ->(notifier_name, exception, env, data) { 
  ... 
}
```

## Throttling Exceptions

You can utilize the `ignore_if` option to perform throttling. Here is an example of how you can perform this.

```ruby
### config/initializers/better_exception_notifier.rb

if ["development", "test"].include?(Rails.env.to_s)
  throttle_interval = 0 ### no throttling for dev
else
  throttle_interval = 5.minutes
end

BetterExceptionNotifier.configure do |config|

  config.ignore_if: ->(env, exception){
    ### Define Identifier for grouping the exceptions
    cache_key = [
      exception.name,
      exception.backtrace.first,
      env.ip,
    ].join("/")

    ### Throttle Logic
    ### We use Rails.cache to store our data in this example, you can use any cache store just be sure it will handle parallel processes
    last_time = Rails.cache.read(cache_key)

    if last_time.present?
      ### expires_in will handle the interval
      
      throttle = true ### throttle the exception
    else
      Rails.cache.store(cache_key, Time.now, expires_in: throttle_interval)

      throttle = false ### do not throttle the exception
    end

    next throttle
  }

}
```

## Exceptions to Email in Development

For recieving exceptions to email from development or test environments you can use the [mailcatcher](https://github.com/sj26/mailcatcher) gem

# Contributing

We test multiple versions of `Rails` using the `appraisal` gem. Please use the following steps to test using `appraisal` locally or you can just use the CI to handle this..

1. `bundle exec appraisal install`
2. `bundle exec appraisal rake test`

For quicker feedback during gem development or debugging feel free to use the provided `rake console` task. It is defined within the [`Rakefile`](./Rakefile).

# Credits

Created & Maintained by [Weston Ganger](https://westonganger.com) - [@westonganger](https://github.com/westonganger)
