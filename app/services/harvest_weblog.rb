class HarvestWeblogs
  # utility class to help with filtering out lines
  class LineRecord
    attr_accessor :event, :event_time, :pid, :ip, :agent


    # save this as a UsageEvent in the database
    def save
      ue = UsageEvent.new
      ue.ip_address = ip
      ue.event_time = event_time
      ue.event = event
      ue.username = user
      ue.pid = pid
      ue.agent = agent
      ue.save
    end
  end

  def self.handle_one_record(r)
     return unless r.status == "200"
     return unless r.method == "GET"
     return if r.agent =~ /(bot|spider|yahoo)/i
     return if r.agent =~ /ruby/i    # our solr harvester agent

     # since all paths are rooted, the first index is always ""
     p = r.path.split('/')
     id = nil

     case p[1]
        when "downloads"
         return if r.path.index("thumbnail") # don't record thumbnail downloads
           r.event = "download"
           id = p[2]
        when "files", "citations"
           r.event = "view"
          x id = p[2]
        when "concern"
           case p[2]
             when "generic_files", "citations"
                r.event = "view"
                id = p[3]
           end
        when "catalog" && p.length == 3
            r.event = "view"
            id = p[2]
     end
     return if id.nil?
     # don't record API accesses
     return if id.end_with?("xml") || id.end_with?("json")
     # remove any prefixes (they shouldn't be there, but make sure)
     id.gsub!('vecnet:', '')
     r.pid = id
     r.save
   end

   def self.parse_file_gz(fname)
    Zlib::GzipReader.open(fname).each_line do |line|
      r = LineRecord.new
      fields = line.split('|')
      r.ip = fields[0]
      r.event_time = DateTime.strptime(fields[2], "%d/%b/%Y:%H:%M:%S %z")
      r.method, r.path = fields[3].split
      r.status = fields[4]
      r.agent = fields[7]

      pt = URI.unescape(fields[11]).strip
      r.pubtkt = pt == '-' ? nil : pt

      handle_one_record(r)
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

     Dir.glob(File.join(config['LOGDIR'],config['LOGFILE_MASK'])) do |fname|
        ingested_files << fname
        next if past_files.include?(fname)
        #self.parse_file_gz(fname)
     end

     if config['WEBLOG_STATEFILE']
       File.open(config['WEBLOG_STATEFILE'], "w") do |f|
         f.write(JSON.generate(ingested_files))
       end
     end
    end
end
