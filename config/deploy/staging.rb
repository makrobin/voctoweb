#deploy-votocweb_sserver ENV['CAP_HOST']roles: %w{app db web}, primary: true, port: ENV['CAP_PORT']
#set :deploy_to,       "/srv/media/#{fetch(:application)}"
#set :tmp_dir,         "/srv/media/#{fetch(:application)}/tmp"
set :tmp_dir, "/var/www/voctoweb_s/tmp"
set :deploy_to, "/var/www/voctoweb_s"
server "voctoweb-app01-stage.c3voc.makandra.de", user: "deploy-votocweb_s", roles: %w{app web}, procfile: "Procfile.sidekiq"

set :bundle_without,  %w(development test sqlite3).join(' ')
set :linked_files,    %w(config/settings.yml config/database.yml config/secrets.yml .env.production .ruby-version)
set :linked_dirs,     %w(log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system)

namespace :fixtures do
  task :apply do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env), FIXTURES_PATH: fetch(:fixtures_path) do
          execute :rake, 'db:fixtures:load'
        end
      end
    end
  end
end
