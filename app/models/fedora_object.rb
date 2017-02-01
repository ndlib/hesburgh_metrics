# A reporting record for an object persisted in Fedora.
class FedoraObject < ActiveRecord::Base
  has_many :fedora_object_aggregation_keys, dependent: :destroy

  def self.generic_files(options={})
    self.where(af_model: 'GenericFile').where('obj_modified_date <= :as_of', as_of: options.fetch(:as_of)).group_by(&options.fetch(:group).to_sym)
  end
end
