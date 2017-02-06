# Harvest Bendo Item Count and Size, save to mysql
#
class HarvestBendoItems
  def self.harvest
    bendo_item = BendoItem.new
    curate_storage_detail = CurateStorageDetail.new
    curate_storage_detail.object_count = bendo_item.count(:all)
    curate_storage_detail.object_bytes = bendo_item.sum(:size)
    curate_storage_detail.storage_type = 'Bendo'
    curate_storage_detail.save
  end
end
