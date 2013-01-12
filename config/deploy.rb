require 'bundler/capistrano'

set :stage, 'production' unless exists? :stage

configuration = YAML.load_file('config/deploy.yml')[stage]

set :application, 'alaveteli'
set :scm, :git
set :deploy_via, :remote_cache
set :repository, configuration['repository']
set :branch, configuration['branch']
set :git_enable_submodules, true
set :deploy_to, configuration['deploy_to']
set :user, configuration['user']
set :use_sudo, false
set :bundle_flags, "--deployment --quiet --binstubs --shebang ruby-local-exec"
set :default_environment, {
    'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH",
    'RBENV_VERSION' => '1.8.7-p371',
    'RAILS_ENV' => 'production'
}

server configuration['server'], :app, :web, :db, :primary => true

namespace :rake do
  namespace :themes do
    task :install do
      run "cd #{current_path} && bundle exec rake themes:install RAILS_ENV=#{rails_env}"
    end
  end
end

# Not in the rake namespace because we're also specifying app-specific arguments here
namespace :xapian do
  desc 'Rebuilds the Xapian index as per the ./scripts/rebuild-xapian-index script'
  task :rebuild_index do
    run "cd #{current_path} && bundle exec rake xapian:rebuild_index models='PublicBody User InfoRequestEvent' RAILS_ENV=#{rails_env}"
  end
end

namespace :deploy do
  desc "Stopping thin"
  task :stop, :roles => :app do
    invoke_command "cd #{shared_path} && thin -C thin.yml stop"
  end

  desc "Starting thin"
  task :start, :roles => :app do
    invoke_command "cd #{shared_path} && thin -C thin.yml start"
  end

  desc "Restarting thin"
  task :restart, :roles => :app do
    invoke_command "cd #{shared_path} && thin -C thin.yml restart"
  end

  desc 'Link configuration after a code update'
  task :symlink_configuration do
    links = {
      "#{release_path}/config/database.yml" => "#{shared_path}/database.yml",
      "#{release_path}/config/general.yml" => "#{shared_path}/general.yml",
      "#{release_path}/config/memcached.yml" => "#{shared_path}/memcached.yml",
      "#{release_path}/config/rails_env.rb" => "#{shared_path}/rails_env.rb",
      "#{release_path}/config/newrelic.yml" => "#{shared_path}/newrelic.yml",
      "#{release_path}/config/aliases" => "#{shared_path}/aliases",
      "#{release_path}/public/foi-live-creation.png" => "#{shared_path}/foi-live-creation.png",
      "#{release_path}/public/foi-user-use.png" => "#{shared_path}/foi-user-use.png",
      "#{release_path}/public/favicon.ico" => "#{shared_path}/favicon.ico",
      "#{release_path}/files" => "#{shared_path}/files",
      "#{release_path}/cache" => "#{shared_path}/cache",
      "#{release_path}/vendor/plugins/acts_as_xapian/xapiandbs" => "#{shared_path}/xapiandbs",
      "#{release_path}/public/download" => "#{release_path}/cache/zips/download"
    }

    # "ln -sf <a> <b>" creates a symbolic link but deletes <b> if it already exists
    run links.map {|a| "ln -sf #{a.last} #{a.first}"}.join(";")
  end

  after 'deploy:setup' do
    run "mkdir -p #{shared_path}/files"
    run "mkdir -p #{shared_path}/cache"
    run "mkdir -p #{shared_path}/xapiandbs"
  end
end

after 'deploy:update_code', 'deploy:symlink_configuration'
after 'deploy:update_code', 'rake:themes:install'

# Put up a maintenance notice if doing a migration which could take a while
before 'deploy:migrate', 'deploy:web:disable'
after 'deploy:migrate', 'deploy:web:enable'

