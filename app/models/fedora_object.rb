# A reporting record for an object persisted in Fedora.
class FedoraObject < ActiveRecord::Base
  has_many :fedora_object_aggregation_keys, dependent: :destroy

  def self.generic_files(options = {})
    group_by = options.fetch(:group)
    modified_date = options.fetch(:as_of)
    where(af_model: 'GenericFile').where('obj_modified_date <= :as_of', as_of: modified_date).group_by(group_by.to_sym)
  end
end
