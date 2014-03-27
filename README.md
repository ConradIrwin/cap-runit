# Capistrano 3 Runit Support

cap-runit provides a helper for building runit services. It lets you easily
deploy services using capistrano 3 and run them with runit.

## Installation

Using bundler: Add `gem 'cap-runit'` to your `Gemfile` and `require 'bundler';
Bundler.require` to your `Capfile`.

Not using bundler: `gem install cap-runit` and add `require 'capistrano/runit'`
to your `Capfile`.

## Usage

cap-runit provides a helper method `runit_service` to Capistrano. As the
philosophy of runit is that everything is just a shell script, `cap-runit`
requires you to write a shell script.

For example, to run sidekiq, you might do something like this:


```ruby
runit_service 'sidekiq' do

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

### Crash notifications

If you need to be notified of when a crash happens in your app, you can also
configure a `finish` script. This is run whenever the `run` script exits.

```ruby
runit_service 'sidekiq' do

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

The service directory needs to be run with `runsvdir` and owned by the
capistrano user. To configure `runsvdir` you can create the following files:


```bash
#/etc/service/cap-runit/run

#!/bin/bash
exec chpst -udeploy -- runsvdir /apps/service 2>&1
```

And

```bash
#/etc/service/cap-runit/log/run

#!/bin/sh
exec svlogd -tt /var/log/cap-runit
```

These files should both be owned by root and `chmod +x`. This way the deploy
user does not need root permissions to reboot a service on deploy.


