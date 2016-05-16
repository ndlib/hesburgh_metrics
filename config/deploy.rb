# List all tasks from RAILS_ROOT using: cap -T
#
# NOTE: The SCM command expects to be at the same path on both the local and
# remote machines. The default git path is: '/shared/git/bin/git'.

set :bundle_roles, [:app, :work]
set :bundle_flags, "--deployment"
require 'bundler/capistrano'
# see http://gembundler.com/v1.3/deploying.html
# copied from https://github.com/carlhuda/bundler/blob/master/lib/bundler/deployment.rb
#
# Install the current Bundler environment. By default, gems will be \
#  installed to the shared/bundle path. Gems in the development and \
#  test group will not be installed. The install command is executed \
#  with the --deployment and --quiet flags. If the bundle cmd cannot \
#  be found then you can override the bundle_cmd variable to specifiy \
#  which one it should use. The base path to the app is fetched from \
#  the :latest_release variable. Set it for custom deploy layouts.
#
#  You can override any of these defaults by setting the variables shown below.
#
#  N.B. bundle_roles must be defined before you require 'bundler/#{context_name}' \
#  in your deploy.rb file.
#
#    set :bundle_gemfile,  "Gemfile"
#    set :bundle_dir,      File.join(fetch(:shared_path), 'bundle')
#    set :bundle_flags,    "--deployment --quiet"
#    set :bundle_without,  [:development, :test]
#    set :bundle_cmd,      "bundle" # e.g. "/opt/ruby/bin/bundle"
#    set :bundle_roles,    #{role_default} # e.g. [:app, :batch]
#############################################################
#  Settings
#############################################################

default_run_options[:pty] = true
set :use_sudo, false
ssh_options[:paranoid] = false
set :default_shell, '/bin/bash'

#############################################################
#  SCM
#############################################################

set :scm, :git
set :deploy_via, :remote_cache

#############################################################
#  Environment
#############################################################

namespace :env do
  desc "Set command paths"
  task :set_paths do
    set :bundle_cmd, '/opt/ruby/current/bin/bundle'
    set :rake,      "#{bundle_cmd} exec rake"
  end
end

#############################################################
#  Database
#############################################################

namespace :db do
  desc "Run the seed rake task."
  task :seed, :roles => :app do
    run "cd #{release_path}; #{rake} RAILS_ENV=#{rails_env} db:seed"
  end
end

#############################################################
#  Deploy
#############################################################

namespace :deploy do
  desc "Execute various commands on the remote environment"
  task :debug, :roles => :app do
    run "/usr/bin/env", :pty => false, :shell => '/bin/bash'
    run "whoami"
    run "pwd"
    run "echo $PATH"
    run "which ruby"
    run "ruby --version"
    run "which rake"
    run "rake --version"
    run "which bundle"
    run "bundle --version"
    run "which git"
  end

  task :stop, :roles => :app do
    # Do nothing.
  end

  desc "Run the migrate rake task."
  task :migrate, :roles => :app do
    run "cd #{release_path}; #{rake} RAILS_ENV=#{rails_env} db:migrate"
  end

  desc "Symlink shared configs and folders on each release."
  task :symlink_shared do
    symlink_targets.each do | source, destination, shared_directory_to_create |
      run "mkdir -p #{File.join( shared_path, shared_directory_to_create)}"
      run "ln -nfs #{File.join( shared_path, source)} #{File.join( release_path, destination)}"
    end
  end

  desc "Setup application symlinks for shared assets"
  task :symlink_setup, :roles => [:app, :web] do
    shared_directories.each { |link| run "mkdir -p #{shared_path}/#{link}" }
  end

  desc "Link assets for current deploy to the shared location"
  task :symlink_update do
    (shared_directories + shared_files).each do |link|
      run "ln -nfs #{shared_path}/#{link} #{release_path}/#{link}"
    end
  end
end

set(:secret_repo_name) {
  case rails_env
  when 'staging' then 'secret_staging'
  when 'pre_production' then 'secret_pprd'
  when 'production' then 'secret_prod'
  end
}


namespace :und do
  task :update_secrets do
    run "cd #{release_path} && ./script/update_secrets.sh #{secret_repo_name}"
  end

  desc "Write the current environment values to file on targets"
  task :write_env_vars do
    put %Q{RAILS_ENV=#{rails_env}
RAILS_ROOT=#{current_path}
}, "#{release_path}/env-vars"
  end

  task :write_build_identifier do
    put "#{branch}", "#{release_path}/BUILD_IDENTIFIER"
  end

  def run_puppet()
    local_module_path = File.join(release_path, 'puppet', 'modules')
    run %Q{sudo puppet apply --modulepath=#{local_module_path}:/global/puppet_standalone/modules:/etc/puppet/modules -e "class { 'lib_metrics': }"}
  end

  desc "Run puppet using the modules supplied by the application"
  task :puppet do
    run_puppet()
  end

end

#############################################################
#  Callbacks
#############################################################

before 'deploy', 'env:set_paths'

#############################################################
#  Configuration
#############################################################

set :application, 'metrics'
set :repository,  "git://github.com/ndlib/hesburgh_metrics.git"

#############################################################
#  Environments
#############################################################

desc "Setup for staging VM"
task :staging do
  # can also set :branch with the :tag variable
  set :branch,    fetch(:branch, fetch(:tag, 'master'))
  set :rails_env, 'staging'
  set :deploy_to, '/home/app/metrics'
  set :user,      'app'
  set :domain,    fetch(:host, 'libvirt9.library.nd.edu')
  set :bundle_without,  [:development, :test, :debug]
  set :shared_directories,  %w(log)
  set :shared_files, %w()

  default_environment['PATH'] = '/opt/ruby/current/bin:$PATH'
  server "#{user}@#{domain}", :app, :work, :web, :db, :primary => true

  after 'deploy:update_code', 'und:write_env_vars', 'und:write_build_identifier', 'und:update_secrets', 'deploy:symlink_update', 'deploy:migrate', 'db:seed'
  after 'deploy', 'deploy:cleanup'
end

desc "Setup for pre-production deploy"
# new one
task :pre_production do
  set :branch,    fetch(:branch, fetch(:tag, 'master'))
  set :rails_env, 'pre_production'
  set :deploy_to, '/home/app/metrics'
  set :user,      'app'
  set :domain,    fetch(:host, 'curatesvrpprd')
  set :bundle_without,  [:development, :test, :debug]
  set :shared_directories,  %w(log)
  set :shared_files, %w()

  default_environment['PATH'] = '/opt/ruby/current/bin:$PATH'
  server "app@curatesvrpprd.library.nd.edu", :app, :web, :db, :primary => true

  after 'deploy:update_code', 'und:write_env_vars', 'und:write_build_identifier', 'und:update_secrets', 'deploy:symlink_update', 'deploy:migrate', 'db:seed'
  after 'deploy', 'deploy:cleanup'
end

desc "Setup for production deploy"
# new one
task :production do
    set :branch,    fetch(:branch, fetch(:tag, 'master'))
    set :rails_env, 'production'
    set :deploy_to, '/home/app/metrics'
    set :user,      'app'
    set :domain,    fetch(:host, 'curatesvrprod')
    set :bundle_without,  [:development, :test, :debug]

    set :shared_directories,  %w(log)
    set :shared_files, %w()


    default_environment['PATH'] = '/opt/ruby/current/bin:$PATH'
    server "app@curatesvrprod.library.nd.edu", :app, :web, :db, :primary => true

    after 'deploy:update_code', 'und:write_env_vars', 'und:write_build_identifier', 'und:update_secrets', 'deploy:symlink_update', 'deploy:migrate', 'db:seed'
    after 'deploy', 'deploy:cleanup'
end
