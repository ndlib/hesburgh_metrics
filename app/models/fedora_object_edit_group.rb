# Object for storing storing & reporting the group edit permissions on object
class FedoraObjectEditGroup < ActiveRecord::Base
  belongs_to :fedora_object
end
