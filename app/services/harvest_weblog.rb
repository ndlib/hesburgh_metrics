require 'ipaddr'

# Harvest a Web Logg, and save to mysql
#
class HarvestWeblogs
  # Util Class that parses a single line
  class LineRecord
    attr_accessor :agent, :event, :event_time,
                  :ip, :method, :path, :pid, :status

    # parse the line record
    def initialize(line)
      fields = line.split(' ')
      @ip = fields[0]
      @event = nil
      @status = fields[9]
      @method = fields[6].sub('"', '')
      @path = fields[7]
      raw_time = fields[3].sub('[', '')
      @event_time = DateTime.strptime(raw_time, '%d/%b/%Y:%H:%M:%S')
      @pid = nil
      @agent = line
    end

    # save the record using the active record framework
    def save
      this_event = FedoraAccessEvent.new
      this_event.pid = pid
      this_event.agent = agent_format(agent)
      this_event.event = event
      this_event.location = ip_format(ip)
      this_event.event_time = event_time
      this_event.save
    end

    def agent_format(agent)
      agent.split('"')[5]
    end

    def ip_format(ip)
      IPAddr.new(ip).mask(24).to_s.split('/')[0]
    end
  end

  # method returns false if line is not to be  logged, true otherwise
  #
  def self.handle_one_record(record)
    return unless record.status == '200'
    return unless record.method == 'GET'
    return if record.agent =~ /(bot|spider|yahoo)/i

    # since all paths are rooted, the first index is always ""
    id = nil

    id = set_pid_event(record, id)

    return if id.nil?
    record.pid = id
    # we made it! save the record
    record.save
  end

  def self.set_pid_event(record, id)
    p = record.path.split('/')

    case p[1]
    when 'downloads'
      id = check_is_download(record, p)
    when 'files', 'citations', 'show', 'collections'
      id = check_is_view(record, p)
    when 'concern'
      id = check_is_concern(record, p)
    end
    id
  end

  def self.check_is_view(record, p)
    record.event = 'view'
    p[2]
  end

  def self.check_is_download(record, p)
    return nil if record.path.index('thumbnail') # skip thumbnail downloads
    record.event = 'download'
    p[2]
  end

  def self.check_is_concern(record, p)
    return nil if record.path.index('new') # don't record /concern/:class/new
    record.event = 'view'
    p[3]
  end

  # Opens a gzipped file, and reads all of the lines
  def self.parse_file_gz(fname)
    Zlib::GzipReader.open(fname).each_line do |line|
      record = LineRecord.new(line)
      handle_one_record(record)
    end
  end

  # Ingest all *.gz files in the given directory
  # the WEBLOG_STATEFILE, if present, list the files
  # arleady harvested- we need not do these again
  #
  def self.harvest_directory(config)
    # keep two lists so files which are deleted are removed
    # from the state_fname file
    past_files = []
    ingested_files = []

    if config['WEBLOG_STATEFILE'] && File.exist?(config['WEBLOG_STATEFILE'])
      past_files = JSON.parse(File.read(config['WEBLOG_STATEFILE']))
    end

    parse_files(config, past_files, ingested_files)

    generate_ingested_filelist(config, ingested_files)
  end

  #
  def self.parse_files(config, past_files, ingested_files)
    Dir.glob(File.join(config['LOGDIR'], config['LOGFILE_MASK'])) do |fname|
      ingested_files << fname
      next if past_files.include?(fname)
      parse_file_gz(fname)
    end
  end

  def self.generate_ingested_filelist(config, ingested_files)
    if config['WEBLOG_STATEFILE']
      File.open(config['WEBLOG_STATEFILE'], 'w') do |f|
        f.write(JSON.generate(ingested_files))
      end
    end
  end
end
