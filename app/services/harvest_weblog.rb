require 'mysql2'

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
  end

  # method returns false if line is not to be  logged, true otherwise
  #
  def self.handle_one_record(r)
     return false unless r.status == "200"
     return false unless r.method == "GET"
     return false if r.agent =~ /(bot|spider|yahoo)/i

     # since all paths are rooted, the first index is always ""
     p = r.path.split('/')
     id = nil

     case p[1]
        when "downloads"
         return false if r.path.index("thumbnail") # don't record thumbnail downloads
           r.event = "download"
           id = p[2]
        when "files", "citations"
           r.event = "view"
           id = p[2]
        when "concern"
         return false if r.path.index("new") # don't record /concern/:class/new
                r.event = "view"
                id = p[3]
        when "show"
            r.event = "view"
            id = p[2]
	when "collections"
	    r.event = "view"
	    id = p[2]
	
     end
     return false if id.nil?
     r.pid = id
     return true
   end

   # Opens a gzipped file, and reads all of the lines
   def self.parse_file_gz(fname)
    Zlib::GzipReader.open(fname).each_line do |line|
      r = LineRecord.new(line)
      db_write_record(r) if handle_one_record(r) == true
    end
   end

   # Ingest all *.gz files in the given directory
   # the WEBLOG_STATEFILE, if present, list the files
   # arleady harvested- we need not do these again
   #
   def self.harvest_directory( config ) 

     db_init(config)

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

    # Attempt to cneect to database- exit if unsuccessful
    def self.db_init( config )
      begin
	@db_connection = Mysql2::Client.new(:host => config['DB_HOST'], :username => config['DB_USER'], :password => config['DB_PASSWORD'], :database => config['DB_NAME'])
      rescue StandardError => e
        puts "Error: #{e}"
        exit 1
      end

    end

    #Write one record to db
    def self.db_write_record( line_record )
      begin
       create_time = DateTime.now
       agent_format = line_record.agent.split('"')[5]
       @db_connection.query("INSERT INTO fedora_access_events VALUES('', \'#{line_record.event}\', \'#{line_record.pid}\', \'#{line_record.ip}\', \'#{line_record.event_time}\', \'#{agent_format}\',\'#{create_time}\',\'#{create_time}\');")
      rescue StandardError => e
        puts "Error: #{e}"
        exit 1
      end
    end

    end
