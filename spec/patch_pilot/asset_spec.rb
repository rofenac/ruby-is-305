# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/patch_pilot'

RSpec.describe PatchPilot::Asset do
  describe 'Windows asset' do
    subject(:asset) do
      described_class.new(
        'hostname' => 'win11-df',
        'ip' => '192.168.1.20',
        'os' => 'windows_desktop',
        'os_version' => '11',
        'role' => 'endpoint',
        'deep_freeze' => true,
        'credential_ref' => 'windows_domain',
        'tags' => %w[endpoint windows deep_freeze]
      )
    end

    it 'stores hostname' do
      expect(asset.hostname).to eq('win11-df')
    end

    it 'stores IP address' do
      expect(asset.ip).to eq('192.168.1.20')
    end

    it 'identifies as Windows' do
      expect(asset).to be_windows
    end

    it 'does not identify as Linux' do
      expect(asset).not_to be_linux
    end

    it 'identifies Deep Freeze status' do
      expect(asset).to be_deep_freeze
    end

    it 'checks tags' do
      expect(asset).to be_tagged('deep_freeze')
      expect(asset).not_to be_tagged('control')
    end

    it 'returns nil for package_manager on Windows' do
      expect(asset.package_manager).to be_nil
    end
  end

  describe 'Linux asset' do
    subject(:asset) do
      described_class.new(
        'hostname' => 'fedora-ws',
        'ip' => '192.168.1.30',
        'os' => 'linux',
        'os_version' => 'fedora',
        'package_manager' => 'dnf',
        'role' => 'workstation',
        'credential_ref' => 'linux_ssh',
        'tags' => %w[workstation linux]
      )
    end

    it 'identifies as Linux' do
      expect(asset).to be_linux
    end

    it 'does not identify as Windows' do
      expect(asset).not_to be_windows
    end

    it 'is not Deep Freeze enabled' do
      expect(asset).not_to be_deep_freeze
    end

    it 'returns package manager' do
      expect(asset.package_manager).to eq('dnf')
    end
  end

  describe 'Docker host' do
    subject(:asset) do
      described_class.new(
        'hostname' => 'ubuntu-docker',
        'ip' => '192.168.1.32',
        'os' => 'linux',
        'docker' => true,
        'tags' => []
      )
    end

    it 'identifies as Docker host' do
      expect(asset).to be_docker_host
    end
  end

  describe '#to_s' do
    subject(:asset) do
      described_class.new(
        'hostname' => 'test-host',
        'ip' => '10.0.0.1',
        'os' => 'linux',
        'tags' => []
      )
    end

    it 'returns readable string' do
      expect(asset.to_s).to eq('test-host (10.0.0.1) - linux')
    end
  end

  describe '#connect' do
    let(:inventory) { instance_double(PatchPilot::Inventory) }

    context 'with Windows asset' do
      subject(:asset) do
        described_class.new(
          'hostname' => 'win-server',
          'ip' => '192.168.1.10',
          'os' => 'windows_server',
          'credential_ref' => 'windows_domain',
          'tags' => []
        )
      end

      let(:credentials) do
        {
          'type' => 'winrm',
          'username' => 'admin',
          'password' => 'secret',
          'domain' => 'CORP'
        }
      end

      before do
        allow(inventory).to receive(:credential).with('windows_domain').and_return(credentials)
      end

      it 'returns WinRM connection' do
        connection = asset.connect(inventory)
        expect(connection).to be_a(PatchPilot::Connections::WinRM)
      end
    end

    context 'with Linux asset' do
      subject(:asset) do
        described_class.new(
          'hostname' => 'linux-server',
          'ip' => '192.168.1.20',
          'os' => 'linux',
          'credential_ref' => 'linux_ssh',
          'tags' => []
        )
      end

      let(:credentials) do
        {
          'type' => 'ssh',
          'username' => 'root',
          'key_file' => '~/.ssh/id_rsa'
        }
      end

      before do
        allow(inventory).to receive(:credential).with('linux_ssh').and_return(credentials)
      end

      it 'returns SSH connection' do
        connection = asset.connect(inventory)
        expect(connection).to be_a(PatchPilot::Connections::SSH)
      end
    end

    context 'without credential_ref' do
      subject(:asset) do
        described_class.new(
          'hostname' => 'no-creds',
          'ip' => '192.168.1.30',
          'os' => 'linux',
          'tags' => []
        )
      end

      it 'raises error' do
        expect { asset.connect(inventory) }
          .to raise_error(PatchPilot::Error, /No credential_ref set/)
      end
    end

    context 'with missing credential' do
      subject(:asset) do
        described_class.new(
          'hostname' => 'missing-cred',
          'ip' => '192.168.1.40',
          'os' => 'linux',
          'credential_ref' => 'nonexistent',
          'tags' => []
        )
      end

      before do
        allow(inventory).to receive(:credential).with('nonexistent').and_return(nil)
      end

      it 'raises error' do
        expect { asset.connect(inventory) }
          .to raise_error(PatchPilot::Error, /Credential not found/)
      end
    end
  end
end
