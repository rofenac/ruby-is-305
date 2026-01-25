# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/patch_pilot'

RSpec.describe PatchPilot::Connection do
  describe '::Result' do
    describe '#success?' do
      it 'returns true when exit_code is 0' do
        result = described_class::Result.new(stdout: '', stderr: '', exit_code: 0)
        expect(result).to be_success
      end

      it 'returns false when exit_code is non-zero' do
        result = described_class::Result.new(stdout: '', stderr: 'error', exit_code: 1)
        expect(result).not_to be_success
      end
    end
  end

  describe '.for' do
    let(:windows_asset) do
      PatchPilot::Asset.new(
        'hostname' => 'win-server',
        'ip' => '192.168.1.10',
        'os' => 'windows_server',
        'tags' => []
      )
    end

    let(:linux_asset) do
      PatchPilot::Asset.new(
        'hostname' => 'linux-server',
        'ip' => '192.168.1.20',
        'os' => 'linux',
        'tags' => []
      )
    end

    let(:unknown_asset) do
      PatchPilot::Asset.new(
        'hostname' => 'unknown',
        'ip' => '192.168.1.30',
        'os' => 'freebsd',
        'tags' => []
      )
    end

    let(:winrm_credentials) do
      {
        'type' => 'winrm',
        'username' => 'admin',
        'password' => 'secret',
        'domain' => 'CORP'
      }
    end

    let(:ssh_credentials) do
      {
        'type' => 'ssh',
        'username' => 'root',
        'key_file' => '~/.ssh/id_rsa'
      }
    end

    it 'returns WinRM connection for Windows assets' do
      connection = described_class.for(windows_asset, winrm_credentials)
      expect(connection).to be_a(PatchPilot::Connections::WinRM)
    end

    it 'returns SSH connection for Linux assets' do
      connection = described_class.for(linux_asset, ssh_credentials)
      expect(connection).to be_a(PatchPilot::Connections::SSH)
    end

    it 'raises error for unsupported OS types' do
      expect do
        described_class.for(unknown_asset, {})
      end.to raise_error(PatchPilot::Connection::UnsupportedAssetError, /freebsd/)
    end

    it 'passes credentials to WinRM connection' do
      connection = described_class.for(windows_asset, winrm_credentials)
      expect(connection.host).to eq('192.168.1.10')
      expect(connection.username).to eq('admin')
      expect(connection.domain).to eq('CORP')
    end

    it 'passes credentials to SSH connection' do
      connection = described_class.for(linux_asset, ssh_credentials)
      expect(connection.host).to eq('192.168.1.20')
      expect(connection.username).to eq('root')
    end
  end
end
