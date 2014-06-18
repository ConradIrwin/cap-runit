#  TODO:CI make this into a gem.

set :runit_service_dir, "/apps/service"

class RunitServiceBuilder

  def initialize(&block)
    instance_eval(&block)
    unless @roles
      raise ArgumentError, "No role configured for runit service"
    end
    unless @run
      raise ArgumentError, "No run script configured for runit service"
    end
  end

  def roles(*roles)
    @roles = roles unless roles == []
    @roles
  end

  def run(str=nil)
    @run = str unless str.nil?
    @run
  end

  def log(str=nil)
    @log = str unless str.nil?
    @log
  end

  def finish(str=nil)
    @finish = str unless str.nil?
    @finish
  end

end

# Defines a runit service.
#
# @example
#
#   # A runit directory that your deploy user can write to.
#   # You can set one of these up using runsvdir.
#
#   set :runit_service_dir, '/etc/service'
#
#   # The first argument is the name of the service.
#   # The remainder are passed to "on" to decide
#   # which servers to use
#   runit_service 'sidekiq', roles(:sidekiq) do
#
#     # required, a bash script that execs your app
#     run <<-EOF
#   #!/bin/bash
#   cd /var/www/app
#   exec bundle exec sidekiq 2>&1
#     EOF
#
#     # optional, a log script that reads stdin/stdout
#     log <<-EOF
#   #!/bin/bash
#   mkdir -p /var/log/app/sidekiq
#   exec syslogd -tt /var/log/app/sidekiq
#     EOF
#
#     # optional, a finish script that runs when your app quits
#     finish <<-EOF
#   #!/bin/bash
#   echo 'QUIT' >> /var/log/app/sidekiq/current
#     EOF
#
#   end
#
def runit_service(name, &block)
  runit_service_dir = fetch(:runit_service_dir)

  service = RunitServiceBuilder.new(&block)

  namespace name do
    desc "Configure #{name} runit"
    task :configure do
      on roles(service.roles), in: :groups, limit: 4 do
        unless test("[ -e #{runit_service_dir}/#{name}/run ]")
          execute <<-EOF
          rm -rf #{runit_service_dir}/#{name}
          mkdir -p #{runit_service_dir}/#{name}/log
          EOF

          upload! StringIO.new(service.run), "#{runit_service_dir}/#{name}/run"

          if service.log
            upload! StringIO.new(service.log), "#{runit_service_dir}/#{name}/log/run"
          end

          if service.finish
            upload! StringIO.new(service.finish), "#{runit_service_dir}/#{name}/finish"
          end

          execute "chmod +x #{runit_service_dir}/#{name}/run #{runit_service_dir}/#{name}/log/run"
        end
      end
    end

    desc "Start #{name}"
    task start: :configure do
      on roles(*service.roles), in: :groups, limit: 4 do
        execute "sv start #{runit_service_dir}/#{name}"
      end
    end

    desc "Stop #{name}"
    task :stop do
      on roles(*service.roles), in: :groups, limit: 4 do
        execute "sv stop #{runit_service_dir}/#{name}"
      end
    end

    desc "Force stop #{name}"
    task :force_stop do
      on roles(*service.roles), in: :groups, limit: 4 do
        execute "sv force-stop #{runit_service_dir}/#{name} || true"
      end
    end
    task :'force-stop' => :force_stop

    desc "Restart #{name}"
    task restart: :configure do
      on roles(*service.roles), in: :groups, limit: 4 do
        execute "sv restart #{runit_service_dir}/#{name}"
      end
    end

    desc "Force restart #{name}"
    task force_restart: :configure do
      on roles(*service.roles), in: :groups, limit: 4 do
        execute "sv force-restart #{runit_service_dir}/#{name} || true"
      end
    end
    task :'force-restart' => :force_restart

    desc "Disable #{name}"
    task :disable do
      on roles(*service.roles), in: :groups, limit: 4 do
        execute "rm -rf #{runit_service_dir}/#{name}"
      end
    end
  end
end
