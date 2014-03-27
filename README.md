# Capistrano 3 Runit Support

cap-runit provides a helper for building runit services. It lets you easily
deploy services using capistrano 3 and run them with runit.

## Installation

#### Using bundler

1. Add `gem 'cap-runit'` to your `Gemfile`
2. Run `bundle install`
3. Add `require 'bundler'; Bundler.require` to your `Capfile`

#### Without bundler

1. Run `gem install cap-runit`
2. Add `require 'capistrano/runit' to your `Capfile`

## Usage

cap-runit provides a helper method `runit_service` to Capistrano. As the
philosophy of runit is that everything is just a shell script, `cap-runit`
requires you to write a shell script.

For example, to run sidekiq, you might do something like this:


```ruby
runit_service 'sidekiq' do

  # Sidekiq should only run on servers with role: %w{sidekiq}
  roles :sidekiq

  run <<-EOF
#!/bin/bash
cd /var/www/app/current
exec bundle exec sidekiq -e production -C ./config/sidekiq.yml 2>&1
  EOF

end
```

This creates three capistrano tasks:

```
cap sidekiq:restart    # Restart bugsnag-event-server
cap sidekiq:start      # Start bugsnag-event-server
cap sidekiq:stop       # Stop bugsnag-event-server
```

If you'd like to restart sidekiq when your app restarts, you also need to
specify:

```ruby
namespace :deploy do
  after :publishing, 'sidekiq:restart'
end
```

### Logging

Runit sends the STDOUT of your `run` script to the `log` script. To get these
logs somewhere useful, you can use any program that reads from STDIN. But
`svlogd` is recommended as it works well with runit and handles log rotation
automatically.

```ruby
runit_service 'sidekiq' do

  roles :sidekiq

  run <<-EOF
#!/bin/bash -l
cd /var/www/app/current
exec bundle exec sidekiq -e production -C ./config/sidekiq.yml 2>&1
  EOF

  log <<-EOF
#!/bin/sh
mkdir -p /var/log/sidekiq
exec svlogd -tt /var/log/sidekiq
  EOF
end
```

N.B. For this example to work you will need to ensure that `/var/log/sidekiq`
can be written to by the capistrano user.

### Crash notifications

If you need to be notified of when a crash happens in your app, you can also
configure a `finish` script. This is run whenever the `run` script exits.

```ruby
runit_service 'sidekiq' do

  roles :sidekiq

  run <<-EOF
#!/bin/bash -l
cd /var/www/app/current
exec bundle exec sidekiq -e production -C ./config/sidekiq.yml 2>&1
  EOF

  log <<-EOF
#!/bin/sh
mkdir -p /var/log/sidekiq
exec svlogd -tt /var/log/sidekiq
  EOF

  finish <<-EOF
#!/bin/sh
export BUGSNAG_API_KEY=bf04f47b034e8df9d22ee75f30fdae6a
[ "$1" = 0 ] || exec bugsnag-runit "$0"
  EOF
end

```

## Configuration

The only configuration variable you need to pass is `runit_service_directory`

```ruby
set :runit_service_directory, "/apps/service"
```

This should point to a directory that is being run by runit, and which the
capistrano user has permission to modify. I suggest setting up something like
`/apps/service` run by the `deploy` user. This can be done by creating two files:


```bash
#/etc/service/cap-runit/run

#!/bin/bash
exec chpst -udeploy -- runsvdir /apps/service 2>&1
```

And

```bash
#/etc/service/cap-runit/log/run

#!/bin/sh
mkdir -p /var/log/cap-runit
exec svlogd -tt /var/log/cap-runit
```

These files should both be owned by root and `chmod +x`. This way the deploy
user does not need root permissions to reboot a service on deploy.
