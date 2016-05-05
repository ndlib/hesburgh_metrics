require 'uri'
require 'zlib'
namespace :metrics do

    desc "Harvest a directory of nginx log files. directory is in HARVEST_DIR env variable. Optional path to state file in HARVEST_STATE."
    task :harvest_weblogs => :environment do
      harvest_config = {}
      harvest_config['DB_NAME'] = ENV['METRICS_DB_NAME']
      harvest_config['DB_USER'] = ENV['METRICS_DB_USER']
      harvest_config['DB_PASSWORD'] = ENV['METRICS_DB_PASSWORD']
      harvest_config['LOGDIR'] = ENV['METRICS_LOGDIR']
      harvest_config['LOGDIR_FILE_MASK'] = ENV['METRICS_L_FILE_MASK']
      harvest_config['LOGFILE_MASK'] = ENV['METRICS_LOGFILE_MASK']
      harvest_config['LOGFILE_FORMAT'] = ENV['METRICS_LOGFILE_FORMAT']
      unless harvest_config['LOGDIR'].nil?
        #HarvestNginx.slurp_directory(hdir, 'access.log-*.gz', hstate)
        harvest_config.print
      end
    end
end
