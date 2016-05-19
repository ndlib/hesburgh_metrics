require 'rails_helper'

RSpec.describe FedoraObjectHarvester do
  context '#harvest' do
    subject { described_class.new.harvest }
    it 'will transform returned objects from a search into FedoraObjects for reporting', functional: true do
      VCR.use_cassette("single_item_search") do
        expect do
          expect do
            subject
          end.to change { FedoraObject.count }.by(1)
        end.to change { FedoraObjectAggregationKey.count }.by(2)
      end
    end
  end

  context '#repo' do
    subject { described_class.new.repo }
    it { is_expected.to respond_to(:search) }
  end
end
