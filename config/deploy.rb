# config valid only for current version of Capistrano
lock '3.5.0'

set :application, 'media-site'
set :repo_url, 'git@github.com:makrobin/voctoweb.git'
set :branch, 'cap-opsc'
#set :user, ENV['CAP_USER']

# temporary deploy scripts, etc
set :tmp_dir, "/var/www/voctoweb_s/tmp"


set :use_sudo,        false
set :stage,           :production
#set :deploy_to,       "/srv/media/#{fetch(:application)}"
set :deploy_to,       "/var/www/voctoweb_s"
#set :ssh_options,     forward_agent: true, user: fetch(:user)
set :bundle_without,  %w(development test sqlite3).join(' ')
set :linked_files,    %w(config/settings.yml config/database.yml config/secrets.yml .env.production .ruby-version)
set :linked_dirs,     %w(log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system)


# sidekiq
#set :init_system, :systemd
#set :service_unit_name, "voctoweb-sidekiq.service"

namespace :deploy do
  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      invoke 'deploy'
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
    end
  end

  ##desc 'Notify IRC about deployment'
  ##task :notify do
  ##  MQTT::Client.connect(ENV['MQTT_URL']) do |c|
  ##    c.publish('/voc/alert', %'{"component": "media-deploy", "msg": "#{revision_log_message} on #{ENV['CAP_HOST']}", "level": "info"}')
  ##  end
  ##end

  after :finishing,    :compile_assets
  after :finishing,    :cleanup
  after :finishing,    :restart
  after :finishing,    :notify
end

namespace :fixtures do
  set :fixtures_path, 'tmp/fixtures_dump'

  desc 'Download fixtures'
  task :download do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env), fixtures_path: fetch(:fixtures_path) do
          execute :mkdir, '-p', fetch(:fixtures_path)
          execute :rake, 'db:fixtures:dump'
        end
      end
      download!("#{current_path}/#{fetch(:fixtures_path)}", 'tmp/', recursive: true)
    end
  end

  desc 'Upload fixtures'
  task :upload do
    on roles(:app) do
      within release_path do
        execute :rm, "-rf #{current_path}/#{fetch(:fixtures_path)}"
      end
      upload!(fetch(:fixtures_path), "#{current_path}/tmp/", recursive: true)
    end
  end
end

namespace :elasticsearch do
  desc 'Create initial index'
  task :create_index do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, "exec rails runner Event.__elasticsearch__.create_index! force: true"
        end
      end
    end
  end

  desc 'Update elasticsearch'
  task :update do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, "exec rails runner Event.import"
        end
      end
    end
  end
end
