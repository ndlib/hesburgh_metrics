# A reporting record for an object persisted in Fedora.
class FedoraObject < ActiveRecord::Base
  has_many :fedora_object_aggregation_keys, dependent: :destroy

  def self.generic_files(options = {})
    sql = "SELECT pid, bytes, mimetype, access_rights FROM #{quoted_table_name}
           where af_model= 'GenericFile' and date(obj_modified_date) <= ?"
    group = options.fetch(:group)
    modified_date = options.fetch(:as_of)
    FedoraObject.find_by_sql([sql, modified_date]).group_by(&group.to_sym)
  end

  def self.group_by_af_model_and_access_rights(options = {})
    modified_date = options.fetch(:as_of)
    reporting_models = options.fetch(:reporting_models)
    where('obj_modified_date <= :as_of', as_of: modified_date)
      .where('af_model in (:af_model_array)', af_model_array: reporting_models)
      .group(:af_model).group(:access_rights).count
  end
end
