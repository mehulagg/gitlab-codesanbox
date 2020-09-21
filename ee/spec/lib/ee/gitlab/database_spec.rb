# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database do
  include ::EE::GeoHelpers

  describe '.read_only?' do
    context 'with Geo enabled' do
      before do
        allow(Gitlab::Geo).to receive(:enabled?) { true }
        allow(Gitlab::Geo).to receive(:current_node) { geo_node }
      end

      context 'is Geo secondary node' do
        let(:geo_node) { create(:geo_node) }

        it 'returns true' do
          expect(described_class.read_only?).to be_truthy
        end
      end

      context 'is Geo primary node' do
        let(:geo_node) { create(:geo_node, :primary) }

        it 'returns false when is Geo primary node' do
          expect(described_class.read_only?).to be_falsey
        end
      end
    end

    context 'with Geo disabled' do
      it 'returns false' do
        expect(described_class.read_only?).to be_falsey
      end
    end
  end

  describe '.healthy?' do
    it 'returns true when replication lag is not too great' do
      allow(Postgresql::ReplicationSlot).to receive(:lag_too_great?).and_return(false)

      expect(described_class.healthy?).to be_truthy
    end

    it 'returns false when replication lag is too great' do
      allow(Postgresql::ReplicationSlot).to receive(:lag_too_great?).and_return(true)

      expect(described_class.healthy?).to be_falsey
    end
  end

  describe '.disable_prepared_statements' do
    it 'disables prepared statements' do
      config = {}

      expect(ActiveRecord::Base.configurations).to receive(:[])
        .with(Rails.env)
        .and_return(config)

      expect(ActiveRecord::Base).to receive(:establish_connection)
        .with({ 'prepared_statements' => false })

      described_class.disable_prepared_statements

      expect(config['prepared_statements']).to eq(false)
    end
  end

  describe '.geo_uncached_queries' do
    context 'when no block is given' do
      it 'raises error' do
        expect do
          described_class.geo_uncached_queries
        end.to raise_error('No block given')
      end
    end

    context 'when the current node is a primary' do
      let!(:primary) { create(:geo_node, :primary) }

      it 'wraps the block in an ActiveRecord::Base.uncached block' do
        stub_current_geo_node(primary)

        expect(Geo::TrackingBase).not_to receive(:uncached)
        expect(ActiveRecord::Base).to receive(:uncached).and_call_original

        expect do |b|
          described_class.geo_uncached_queries(&b)
        end.to yield_control
      end
    end

    context 'when the current node is a secondary' do
      let!(:primary) { create(:geo_node, :primary) }
      let!(:secondary) { create(:geo_node) }

      it 'wraps the block in a Geo::TrackingBase.uncached block and an ActiveRecord::Base.uncached block' do
        stub_current_geo_node(secondary)

        expect(Geo::TrackingBase).to receive(:uncached).and_call_original
        expect(ActiveRecord::Base).to receive(:uncached).and_call_original

        expect do |b|
          described_class.geo_uncached_queries(&b)
        end.to yield_control
      end
    end

    context 'when there is no current node' do
      it 'wraps the block in an ActiveRecord::Base.uncached block' do
        expect(Geo::TrackingBase).not_to receive(:uncached)
        expect(ActiveRecord::Base).to receive(:uncached).and_call_original

        expect do |b|
          described_class.geo_uncached_queries(&b)
        end.to yield_control
      end
    end
  end
end
