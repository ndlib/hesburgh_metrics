# frozen_string_literal: true

# Class to store periodic report metrics.
class ReportingStorageDetail
  include ActiveModel::Model
  attr_accessor :count, :size
end
