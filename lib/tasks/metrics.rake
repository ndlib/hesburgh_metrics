namespace :metrics do
  desc "Harvest a directory of webserver log files. Webserver log directory is in METRICS_LOGDIR env variable."
  task :harvest_weblogs => :environment do

    require 'uri'
    require 'zlib'
    require 'harvest_weblog'
  
    harvest_config = {}
    harvest_config['LOGDIR'] = ENV['METRICS_LOGDIR']
    harvest_config['LOGDIR_FILE_MASK'] = ENV['METRICS_L_FILE_MASK']
    harvest_config['LOGFILE_MASK'] = ENV['METRICS_LOGFILE_MASK']
    harvest_config['LOGFILE_FORMAT'] = ENV['METRICS_LOGFILE_FORMAT']
    harvest_config['WEBLOG_STATEFILE'] = ENV['METRICS_WEBLOG_STATEFILE']
    unless harvest_config['LOGDIR'].nil?
      HarvestWeblogs.harvest_directory(harvest_config)
    end
  end
end
