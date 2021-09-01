# frozen_string_literal: true

# Harvest Bendo Item Count and Size, save to mysql
# using Activerecord magic
class HarvestBendoItems
  def self.harvest
    curate_storage_detail = CurateStorageDetail.new
    curate_storage_detail.object_count = BendoItem.count(:all)
    curate_storage_detail.object_bytes = BendoItem.sum(:size)
    curate_storage_detail.storage_type = 'Bendo'
    curate_storage_detail.harvest_date = Time.zone.now
    curate_storage_detail.save
  end
end
