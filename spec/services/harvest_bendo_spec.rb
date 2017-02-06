require 'spec_helper'
require 'harvest_bendo'

RSpec.describe HarvestBendoItems do
  it 'creates a Harvested Files directory file', memfs: true do
    begin
      # Should add a row to CurateStorageDetail
      expect do
        HarvestBendoItems.harvest
      end.to change { CurateStorageDetail.count }.by(1)
    end
  end
end
