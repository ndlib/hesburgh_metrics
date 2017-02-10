require 'rails_helper'

RSpec.describe BendoItem do
  describe '.table_name' do
    subject { described_class.table_name }
    it { is_expected.to eq('items') }
  end
end
