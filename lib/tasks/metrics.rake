# frozen_string_literal: true

namespace :metrics do
  desc 'Harvest log files. Directory is in METRICS_LOGDIR env variable.'
  task harvest_weblogs: :environment do
    require 'uri'
    require 'zlib'
    require 'harvest_weblog'

    harvest_config = {}
    harvest_config['LOGDIR'] = ENV['METRICS_LOGDIR']
    harvest_config['LOGDIR_FILE_MASK'] = ENV['METRICS_L_FILE_MASK']
    harvest_config['LOGFILE_MASK'] = ENV['METRICS_LOGFILE_MASK']
    harvest_config['LOGFILE_FORMAT'] = ENV['METRICS_LOGFILE_FORMAT']
    harvest_config['WEBLOG_STATEFILE'] = ENV['METRICS_WEBLOG_STATEFILE']
    HarvestWeblogs.harvest_directory(harvest_config) unless harvest_config['LOGDIR'].nil?
  end

  desc 'Harvest fedora objects via the Fedora API.'
  task harvest_fedora: :environment do
    require 'fedora_object_harvester'
    FedoraObjectHarvester.new.harvest
  end

  desc 'Harvest Bendo Item Count and Size.'
  task harvest_bendo: :environment do
    require 'harvest_bendo_items'
    HarvestBendoItems.harvest
  end

  desc 'Create Periodic Metrics Report for given date Range'
  task generate_report: :environment do
    require 'metrics_report'
    MetricsReport.new(ENV['METRICS_START_DATE'], ENV['METRICS_END_DATE']).generate_report
  end
end
