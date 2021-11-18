# SlowRide

When you've enabled a feature flag (for example, with [Flipper](https://github.com/jnunemaker/flipper) or [LaunchDarkly](https://launchdarkly.com)), what often follows is that a human being has to pay attention to error rates or, at the very least, respond to alerts about an increase in those error rates.

With SlowRide, you can take it easy.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'slow_ride'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install slow_ride

## Usage

SlowRide was designed around the idea of pluggable backends. Right now, however, Redis is the only backend offered.

### Redis

SlowRide can use Redis to store the check and failure counts. To use it, load the SlowRide and Redis gems and define how you connect to Redis:

```ruby
require "redis"
require "slow_ride"

# The `redis` gem uses ENV["REDIS_URL"] by default, so if you use that env var
# you can simply use `Redis.new` for your Redis block.
SlowRide.enable_redis { Redis.new }
```

Define your feature by giving it a name, a failure threshold, a minimum number of checks (defaults to 1000), and a way to disable the feature flag.

```ruby
# If we reach 20% failures, shut off the feature.
MY_FEATURE = SlowRide::Redis.new("my-feature", failure_threshold: 0.2) do
  Flipper.disable "my-feature"
end
```

You can also notify your team that the feature flag has been disabled:

```ruby
MY_FEATURE = SlowRide::Redis.new(:my_feature, failure_threshold: 0.2) do
  Flipper.disable :my_feature
  Slack.notify "#slow-ride", "Feature `my-feature` has exceeded 20% failures and has been disabled"
end
```

Then, in your feature-flag code paths, you call `MY_FEATURE.check { ... }`:

```ruby
if Flipper.enabled? :my_feature
  MY_FEATURE.check { new_hotness! }
else
  old_and_busted!
end
```

_Please do not use this gem as a replacement for error reporting!_ I mean, you can do whatever you like and I can't stop you, but I'll be sad if you use it this way. The intent is that the block twiddles whatever bits it needs to in order to ensure the feature isn't checked anymore at all — such as by disabling a feature flag.

You can also pass a couple other options:

- `minimum_checks:` — the number of checks required to be run before SlowRide invokes the feature's block
- `max_duration:` — the number of seconds to store the feature data in Redis

#### Cleanup

Redis-backed features will automatically clean up after themselves.

- When a failure threshold is reached, the data is automatically deleted from Redis.
- If a failure threshold is never reached before removing the feature flag from your code, the data will expire from Redis after a default duration of one week.

You can override the max storage duration for any reason by passing `max_duration:` to the feature definition. The default is one week and assumes that feature checks will happen far more often than that. This way, you don't need to delete anything manually when you remove a feature flag from your codebase.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jgaskins/slow_ride. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/jgaskins/slow_ride/blob/main/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the SlowRide project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/jgaskins/slow_ride/blob/main/CODE_OF_CONDUCT.md).
