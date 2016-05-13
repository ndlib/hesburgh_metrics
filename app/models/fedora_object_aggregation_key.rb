# Value object for storing storing Fedora identifiers
class FedoraObjectAggregationKey < ActiveRecord::Base
  belongs_to :fedora_object
end
