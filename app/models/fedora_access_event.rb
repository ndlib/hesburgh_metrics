# A usage record for every access harvested from weblog.
class FedoraAccessEvent < ActiveRecord::Base
  REGEXP_FOR_CAMPUS_IP = "^129.74|^10.|^172.22|^192.168".freeze

  def self.all_on_campus_usage(options = {})
    sql = " select event, count(pid) as event_count
            from fedora_access_events
            where location REGEXP ? and event_time >= ? and event_time <= ?
            group by event"
    start_date = options.fetch(:start_date)
    end_date = options.fetch(:end_date)
    FedoraAccessEvent.find_by_sql([sql, REGEXP_FOR_CAMPUS_IP, start_date, end_date])
  end

  def self.distinct_on_campus_usage(options = {})
    sql = " select event, count(distinct pid) as event_count
            from fedora_access_events
            where location REGEXP ? and event_time >= ? and event_time <= ?
            group by event"
    start_date = options.fetch(:start_date)
    end_date = options.fetch(:end_date)
    FedoraAccessEvent.find_by_sql([sql, REGEXP_FOR_CAMPUS_IP, start_date, end_date])
  end

  def self.all_off_campus_usage(options = {})
    sql = " select event, count(pid) as event_count
            from fedora_access_events
            where location not REGEXP ? and event_time >= ? and event_time <= ?
            group by event"
    start_date = options.fetch(:start_date)
    end_date = options.fetch(:end_date)
    FedoraAccessEvent.find_by_sql([sql, REGEXP_FOR_CAMPUS_IP, start_date, end_date])
  end

  def self.distinct_off_campus_usage(options = {})
    sql = " select event, count(distinct pid) as event_count
            from fedora_access_events
            where location not REGEXP ? and event_time >= ? and event_time <= ?
            group by event"
    start_date = options.fetch(:start_date)
    end_date = options.fetch(:end_date)
    FedoraAccessEvent.find_by_sql([sql, REGEXP_FOR_CAMPUS_IP, start_date, end_date])
  end

  def self.item_usage_by_type(options = {})
    sql = " select a.parent_type as item_type, b.event as event, count(b.pid) as object_count from `fedora_access_events` b
            INNER JOIN `fedora_objects` a on a.pid = b.pid
            where b.event_time >= ? and b.event_time <= ?
            group by a.parent_type, b.event"
    start_date = options.fetch(:start_date)
    end_date = options.fetch(:end_date)
    FedoraAccessEvent.find_by_sql([sql, start_date, end_date])
  end

  def self.top_viewed_objects(options = {})
    sql = "SELECT b.pid, count(b.pid) as count, a.resource_type as item_type, a.title as title
           FROM fedora_access_events b
           INNER JOIN `fedora_objects` a on a.pid = b.pid
           where b.event='view'
           GROUP BY b.pid ORDER BY count(b.pid) DESC LIMIT ?"
    number_of_items = options.fetch(:number_of_items, 10)
    FedoraAccessEvent.find_by_sql([sql, number_of_items])
  end

  def self.top_downloaded_objects(options = {})
    sql = " SELECT b.pid, count(b.pid) as count, a.title as title , a.parent_pid as parent_pid,
            (select title from fedora_objects where pid= a.parent_pid) as parent_title, a.parent_type as parent_type
            FROM fedora_access_events b
            INNER JOIN `fedora_objects` a on a.pid = b.pid
            where b.event='download'
            GROUP BY b.pid ORDER BY count(b.pid) DESC LIMIT ? "
    number_of_items = options.fetch(:number_of_items, 10)
    FedoraAccessEvent.find_by_sql([sql, number_of_items])
  end
end
