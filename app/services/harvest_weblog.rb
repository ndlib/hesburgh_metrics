require 'mysql2'
require 'ipaddr'

# Harvest a Web Logg, and save to mysql
#
class HarvestWeblogs
  @db_connection = nil

  #Util Class that parses a single line
  class LineRecord
    attr_accessor :agent, :event, :event_time, :ip, :method, :path, :pid, :status


    # parse the line record
    def initialize(line)
      fields = line.split(' ')
      @ip = fields[0]
      @event = nil 
      @status = fields[9]
      @method = fields[6].sub('"','')
      @path = fields[7]
      @event_time = DateTime.strptime(fields[3].sub('[',''), "%d/%b/%Y:%H:%M:%S")
      @pid  = nil
      @agent = line
    end

    # save the record using the active record framework
    def save
      event = FedoraAccessEvent.new
      create_time = DateTime.now
      agent_format = agent.split('"')[5]
      event.pid = pid
      event.agent = agent_format
      event.event = event
      event.location = IPAddr.new(ip).mask(24).to_s.split("/")[0]
      event.event_time = event_time
      event.created_at = create_time
      event.updated_at = create_time
      event.save
    end
  end

  # method returns false if line is not to be  logged, true otherwise
  #
  def self.handle_one_record(record)
     return unless record.status == "200"
     return unless record.method == "GET"
     return if record.agent =~ /(bot|spider|yahoo)/i

     # since all paths are rooted, the first index is always ""
     p = record.path.split('/')
     id = nil

     case p[1]
       when "downloads"
         return if record.path.index("thumbnail") # don't record thumbnail downloads
         record.event = "download"
         id = p[2]
       when "files", "citations"
         record.event = "view"
          id = p[2]
       when "concern"
         return if record.path.index("new") # don't record /concern/:class/new
         record.event = "view"
         id = p[3]
       when "show"
         record.event = "view"
         id = p[2]
       when "collections"
         record.event = "view"
         id = p[2]
     end
     return if id.nil?
     record.pid = id
     # we made it! save the record
     record.save
     return 
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
   def self.harvest_directory( config ) 

     # keep two lists so files which are deleted are removed
     # from the state_fname file
     past_files = []
     ingested_files = []
     if config['WEBLOG_STATEFILE'] && File.exist?(config['WEBLOG_STATEFILE'])
        past_files = JSON.parse(File.read(config['WEBLOG_STATEFILE']))
     end

     Dir.glob(File.join(config['LOGDIR'],config['LOGFILE_MASK'])) do |fname|
        ingested_files << fname
        next if past_files.include?(fname)
        self.parse_file_gz(fname)
     end

     if config['WEBLOG_STATEFILE']
       File.open(config['WEBLOG_STATEFILE'], "w") do |f|
         f.write(JSON.generate(ingested_files))
       end
     end
    end
end
