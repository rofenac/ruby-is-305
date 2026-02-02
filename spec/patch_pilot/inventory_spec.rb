# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/patch_pilot'

RSpec.describe PatchPilot::Inventory do
  describe '.load' do
    context 'with valid inventory file' do
      subject(:inventory) { described_class.load(inventory_path) }

      let(:inventory_path) { File.expand_path('../../config/inventory.yml', __dir__) }

      it 'loads all assets' do
        expect(inventory.count).to eq(8)
      end

      it 'loads credentials' do
        expect(inventory.credentials).to have_key('windows_domain')
        expect(inventory.credentials).to have_key('linux_ssh')
      end
    end

    context 'with missing file' do
      it 'raises an error' do
        expect do
          described_class.load('/nonexistent/path.yml')
        end.to raise_error(PatchPilot::Error, /not found/)
      end
    end
  end

  describe 'filtering methods' do
    subject(:inventory) { described_class.load(inventory_path) }

    let(:inventory_path) { File.expand_path('../../config/inventory.yml', __dir__) }

    describe '#windows' do
      it 'returns only Windows assets' do
        expect(inventory.windows).to all(be_windows)
        expect(inventory.windows.count).to eq(5)
      end
    end

    describe '#linux' do
      it 'returns only Linux assets' do
        expect(inventory.linux).to all(be_linux)
        expect(inventory.linux.count).to eq(3)
      end
    end

    describe '#deep_freeze_enabled' do
      it 'returns only Deep Freeze assets' do
        df_assets = inventory.deep_freeze_enabled
        expect(df_assets.count).to eq(1)
        expect(df_assets.first.hostname).to eq('PC1')
      end
    end

    describe '#control_endpoints' do
      it 'returns Windows endpoints without Deep Freeze' do
        controls = inventory.control_endpoints
        expect(controls.count).to eq(2)
        expect(controls).to all(be_windows)
        expect(controls.map(&:deep_freeze?)).to all(be false)
      end
    end

    describe '#docker_hosts' do
      it 'returns Docker hosts' do
        docker = inventory.docker_hosts
        expect(docker.count).to eq(1)
        expect(docker.first.hostname).to eq('ubuntu-docker')
      end
    end

    describe '#by_tag' do
      it 'filters by tag' do
        infrastructure = inventory.by_tag('infrastructure')
        expect(infrastructure.count).to eq(2)
      end
    end

    describe '#by_role' do
      it 'filters by role' do
        endpoints = inventory.by_role('endpoint')
        expect(endpoints.count).to eq(3)
      end
    end

    describe '#find' do
      it 'finds asset by hostname' do
        asset = inventory.find('dc01')
        expect(asset).not_to be_nil
        expect(asset.role).to eq('domain_controller')
      end

      it 'returns nil for unknown hostname' do
        expect(inventory.find('nonexistent')).to be_nil
      end
    end

    describe '#credential' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('DOMAIN_ADMIN_USER', nil).and_return('admin')
        allow(ENV).to receive(:fetch).with('DOMAIN_ADMIN_PASSWORD', nil).and_return('password')
        allow(ENV).to receive(:fetch).with('DOMAIN_NAME', nil).and_return('TESTLAB')
        allow(ENV).to receive(:fetch).with('SSH_USER', nil).and_return('root')
        allow(ENV).to receive(:fetch).with('SSH_PASSWORD', nil).and_return('password')
      end

      it 'returns credential config by reference' do
        cred = inventory.credential('windows_domain')
        expect(cred['type']).to eq('winrm')
      end

      it 'resolves environment variables' do
        cred = inventory.credential('windows_domain')
        expect(cred['username']).to eq('admin')
        expect(cred['domain']).to eq('TESTLAB')
      end

      it 'returns nil for unknown credential' do
        expect(inventory.credential('nonexistent')).to be_nil
      end
    end
  end

  describe '#summary' do
    subject(:inventory) { described_class.load(inventory_path) }

    let(:inventory_path) { File.expand_path('../../config/inventory.yml', __dir__) }

    it 'returns summary string' do
      summary = inventory.summary
      expect(summary).to include('Total assets: 8')
      expect(summary).to include('Windows: 5')
      expect(summary).to include('Linux: 3')
      expect(summary).to include('Deep Freeze enabled: 1')
    end
  end
end
