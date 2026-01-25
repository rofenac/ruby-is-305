# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'
require_relative '../../../lib/patch_pilot/connections/winrm'

RSpec.describe PatchPilot::Connections::WinRM do
  subject(:connection) do
    described_class.new(
      host: '192.168.1.10',
      username: 'admin',
      password: 'secret',
      domain: 'CORP'
    )
  end

  describe '#initialize' do
    it 'stores connection parameters' do
      expect(connection.host).to eq('192.168.1.10')
      expect(connection.username).to eq('admin')
      expect(connection.domain).to eq('CORP')
      expect(connection.port).to eq(5985)
    end

    it 'allows custom port' do
      conn = described_class.new(
        host: '192.168.1.10',
        username: 'admin',
        password: 'secret',
        port: 5986
      )
      expect(conn.port).to eq(5986)
    end
  end

  describe '#connect' do
    let(:mock_connection) { instance_double(WinRM::Connection) }
    let(:mock_shell) { instance_double(WinRM::Shells::Powershell) }

    before do
      allow(WinRM::Connection).to receive(:new).and_return(mock_connection)
      allow(mock_connection).to receive(:shell).with(:powershell).and_return(mock_shell)
    end

    it 'establishes connection and returns self' do
      result = connection.connect
      expect(result).to eq(connection)
    end

    it 'creates WinRM connection with correct endpoint' do
      connection.connect
      expect(WinRM::Connection).to have_received(:new).with(
        hash_including(endpoint: 'http://192.168.1.10:5985/wsman')
      )
    end

    it 'uses domain\\username format when domain is set' do
      connection.connect
      expect(WinRM::Connection).to have_received(:new).with(
        hash_including(user: 'CORP\\admin')
      )
    end

    context 'when authentication fails' do
      before do
        allow(WinRM::Connection).to receive(:new)
          .and_raise(WinRM::WinRMAuthorizationError.new('Unauthorized'))
      end

      it 'raises AuthenticationError' do
        expect { connection.connect }
          .to raise_error(PatchPilot::Connection::AuthenticationError, /Authentication failed/)
      end
    end

    context 'when connection is refused' do
      before do
        allow(WinRM::Connection).to receive(:new).and_raise(Errno::ECONNREFUSED)
      end

      it 'raises ConnectionError' do
        expect { connection.connect }
          .to raise_error(PatchPilot::Connection::ConnectionError, /Failed to connect/)
      end
    end
  end

  describe '#execute' do
    let(:mock_connection) { instance_double(WinRM::Connection) }
    let(:mock_shell) { instance_double(WinRM::Shells::Powershell) }
    let(:mock_output) { instance_double(WinRM::Output, stdout: "dc01\n", stderr: '', exitcode: 0) }

    before do
      allow(WinRM::Connection).to receive(:new).and_return(mock_connection)
      allow(mock_connection).to receive(:shell).with(:powershell).and_return(mock_shell)
      allow(mock_shell).to receive(:run).and_return(mock_output)
    end

    it 'returns Result with command output' do
      connection.connect
      result = connection.execute('hostname')

      expect(result).to be_a(PatchPilot::Connection::Result)
      expect(result.stdout).to eq("dc01\n")
      expect(result.stderr).to eq('')
      expect(result.exit_code).to eq(0)
    end

    it 'auto-connects if not connected' do
      result = connection.execute('hostname')
      expect(result.stdout).to eq("dc01\n")
    end

    context 'when command fails' do
      let(:mock_output) { instance_double(WinRM::Output, stdout: '', stderr: 'error', exitcode: 1) }

      it 'returns Result with error details' do
        connection.connect
        result = connection.execute('bad-command')

        expect(result.stderr).to eq('error')
        expect(result.exit_code).to eq(1)
        expect(result).not_to be_success
      end
    end
  end

  describe '#close' do
    let(:mock_connection) { instance_double(WinRM::Connection) }
    let(:mock_shell) { instance_double(WinRM::Shells::Powershell) }

    before do
      allow(WinRM::Connection).to receive(:new).and_return(mock_connection)
      allow(mock_connection).to receive(:shell).with(:powershell).and_return(mock_shell)
      allow(mock_shell).to receive(:close)
    end

    it 'closes the shell' do
      connection.connect
      connection.close
      expect(mock_shell).to have_received(:close)
    end

    it 'marks connection as disconnected' do
      connection.connect
      expect(connection).to be_connected
      connection.close
      expect(connection).not_to be_connected
    end
  end
end
