# Leverage the following methods to get the stats out of bendo
# BendoItem.count
# BendoItem.sum(:size)
class BendoItem < ActiveRecord::Base
  self.table_name = 'items'
  # Note, secrets will determine what we are actually connecting to
  establish_connection "bendo"
end
