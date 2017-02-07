require 'spec_helper'
require 'harvest_bendo'

# rspec test fro DLPT-818
RSpec.describe HarvestBendoItems do
  it 'reads count and size from a bendo item and creates a curates storage detail item.' do
    begin
      # Stub out a BendoItem for our test
      BendoItem = double
      expect(BendoItem).to receive(:count).and_return(10)
      expect(BendoItem).to receive(:sum).and_return(1000)

      # Should add a row to CurateStorageDetail
      expect do
        HarvestBendoItems.harvest
      end.to change { CurateStorageDetail.count }.by(1)
      # Verify CurateStorageDetail Fields
      expect(CurateStorageDetail.last.storage_type).to eq('Bendo')
      expect(CurateStorageDetail.last.object_bytes).to eq(1000)
      expect(CurateStorageDetail.last.object_count).to eq(10)
    end
  end
end
