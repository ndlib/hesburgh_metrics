require 'spec_helper'
require 'harvest_weblog'

RSpec.describe HarvestWeblogs do
  it 'creates a Harvested Files directory file', memfs: true do
    # Test file dir
    testdir = Dir.mktmpdir
    ingestfile = File.join(testdir, 'metrics_files_ingested')

    # set HarvestWeblogs configuration
    harvest_config = {}
    harvest_config['LOGDIR'] = testdir
    harvest_config['LOGFILE_MASK'] = 'access.log-*.gz'
    harvest_config['WEBLOG_STATEFILE'] = ingestfile

    # A day of data from the production webserver - 403 download/shows
    FileUtils.cp('spec/fixtures/logfiles/access.log-20160517.gz', testdir)
    # Test data for https://github.com/ndlib/hesburgh_metrics/issues/48
    FileUtils.cp('spec/fixtures/logfiles/access.log-20160706.gz', testdir)
    # Test data for DLTP-1622 
    FileUtils.cp('spec/fixtures/logfiles/access.log-20190221.gz', testdir)

    begin
      # run 1 day's worth of data. This covers all the content types and bad return legs
      expect(File.exist?(ingestfile)).to be false
      expect do
        HarvestWeblogs.harvest_directory(harvest_config)
      end.to change { FedoraAccessEvent.count }.by(1690)

      # ingested history should be created
      expect(File.exist?(ingestfile)).to be true

      # rerun- should detect ingest history, and not repeat itself
      expect do
        HarvestWeblogs.harvest_directory(harvest_config)
      end.to change { FedoraAccessEvent.count }.by(0)
    ensure
      # remove the directory.
      FileUtils.remove_entry testdir
    end
  end
end
