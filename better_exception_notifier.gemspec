# require File.expand_path('lib/better_exception_notifier/version', __dir__)

Gem::Specification.new do |s|
  s.name = 'better_exception_notifier'
  s.version = BetterExceptionNotifier::VERSION
  s.summary       = "Easy-to-use exception notifier for Rails and Rack applications."
  s.description   = s.summary
  s.homepage      = "https://github.com/westonganger/better_exception_notifier"
  s.license       = "MIT"
  s.authors = ["Weston Ganger"]
  s.email = ["weston@westonganger.com"]

  s.metadata["source_code_uri"] = s.homepage
  s.metadata["changelog_uri"] = File.join(s.homepage, "blob/master/CHANGELOG.md")

  s.files = Dir.glob("{lib/**/*}") + %w{ LICENSE README.md Rakefile CHANGELOG.md }
  s.test_files  = Dir.glob("{test/**/*}")
  s.require_path = 'lib'

  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  s.add_dependency 'actionmailer', '>= 4.0'
  s.add_dependency 'activesupport', '>= 4.0'

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'aws-sdk-sns'
  s.add_development_dependency 'carrier-pigeon'
  s.add_development_dependency 'dogapi'
  s.add_development_dependency 'hipchat'
  s.add_development_dependency 'httparty'
  s.add_development_dependency "minitest"
  s.add_development_dependency "minitest-reporters"
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'mock_redis'
  s.add_development_dependency 'rails'
  s.add_development_dependency 'sidekiq'
  s.add_development_dependency 'slack-notifier'
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'tinder'

  if RUBY_VERSION.to_f >= 2.4
    s.add_development_dependency "warning"
  end
end
