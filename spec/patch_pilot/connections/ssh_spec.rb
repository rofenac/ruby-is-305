# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'
require_relative '../../../lib/patch_pilot/connections/ssh'

RSpec.describe PatchPilot::Connections::SSH do
  subject(:connection) do
    described_class.new(
      host: '192.168.1.30',
      username: 'admin',
      key_file: '~/.ssh/id_rsa'
    )
  end

  describe '#initialize' do
    it 'stores connection parameters' do
      expect(connection.host).to eq('192.168.1.30')
      expect(connection.username).to eq('admin')
      expect(connection.port).to eq(22)
    end

    it 'expands key_file path' do
      expect(connection.key_file).to eq(File.expand_path('~/.ssh/id_rsa'))
    end

    it 'allows custom port' do
      conn = described_class.new(
        host: '192.168.1.30',
        username: 'admin',
        password: 'secret',
        port: 2222
      )
      expect(conn.port).to eq(2222)
    end

    it 'handles nil key_file' do
      conn = described_class.new(
        host: '192.168.1.30',
        username: 'admin',
        password: 'secret'
      )
      expect(conn.key_file).to be_nil
    end
  end

  describe '#connect' do
    let(:mock_session) { instance_double(Net::SSH::Connection::Session, closed?: false) }

    before do
      allow(Net::SSH).to receive(:start).and_return(mock_session)
    end

    it 'establishes connection and returns self' do
      result = connection.connect
      expect(result).to eq(connection)
    end

    it 'passes correct options for key-based auth' do
      connection.connect
      expect(Net::SSH).to have_received(:start).with(
        '192.168.1.30',
        'admin',
        hash_including(
          keys: [File.expand_path('~/.ssh/id_rsa')],
          keys_only: true
        )
      )
    end

    context 'with password authentication' do
      subject(:connection) do
        described_class.new(
          host: '192.168.1.30',
          username: 'admin',
          password: 'secret'
        )
      end

      it 'passes password option' do
        connection.connect
        expect(Net::SSH).to have_received(:start).with(
          '192.168.1.30',
          'admin',
          hash_including(password: 'secret')
        )
      end
    end

    context 'when authentication fails' do
      before do
        allow(Net::SSH).to receive(:start)
          .and_raise(Net::SSH::AuthenticationFailed.new('admin'))
      end

      it 'raises AuthenticationError' do
        expect { connection.connect }
          .to raise_error(PatchPilot::Connection::AuthenticationError, /Authentication failed/)
      end
    end

    context 'when connection is refused' do
      before do
        allow(Net::SSH).to receive(:start).and_raise(Errno::ECONNREFUSED)
      end

      it 'raises ConnectionError' do
        expect { connection.connect }
          .to raise_error(PatchPilot::Connection::ConnectionError, /Failed to connect/)
      end
    end

    context 'when host cannot be resolved' do
      before do
        allow(Net::SSH).to receive(:start)
          .and_raise(SocketError.new('getaddrinfo: Name or service not known'))
      end

      it 'raises ConnectionError' do
        expect { connection.connect }
          .to raise_error(PatchPilot::Connection::ConnectionError, /DNS resolution failed/)
      end
    end
  end

  describe '#execute' do
    let(:mock_session) { instance_double(Net::SSH::Connection::Session, closed?: false) }
    let(:mock_channel) { instance_double(Net::SSH::Connection::Channel) }

    before do
      allow(Net::SSH).to receive(:start).and_return(mock_session)
      allow(mock_session).to receive(:open_channel).and_yield(mock_channel)
      allow(mock_session).to receive(:loop)
      allow(mock_channel).to receive(:exec).and_yield(mock_channel, true)
      allow(mock_channel).to receive(:on_data).and_yield(mock_channel, "fedora-ws\n")
      allow(mock_channel).to receive(:on_extended_data)
      allow(mock_channel).to receive(:on_request).with('exit-status')
    end

    it 'returns Result with command output' do
      connection.connect
      result = connection.execute('hostname')

      expect(result).to be_a(PatchPilot::Connection::Result)
      expect(result.stdout).to eq("fedora-ws\n")
      expect(result.exit_code).to eq(0)
    end

    it 'auto-connects if not connected' do
      result = connection.execute('hostname')
      expect(result.stdout).to eq("fedora-ws\n")
    end

    context 'when command execution fails' do
      before do
        allow(mock_channel).to receive(:exec).and_yield(mock_channel, false)
      end

      it 'raises CommandError' do
        connection.connect
        expect { connection.execute('bad-command') }
          .to raise_error(PatchPilot::Connection::CommandError, /Failed to execute/)
      end
    end
  end

  describe '#close' do
    let(:mock_session) { instance_double(Net::SSH::Connection::Session, closed?: false) }

    before do
      allow(Net::SSH).to receive(:start).and_return(mock_session)
      allow(mock_session).to receive(:close)
    end

    it 'closes the session' do
      connection.connect
      connection.close
      expect(mock_session).to have_received(:close)
    end

    it 'marks connection as disconnected' do
      connection.connect
      expect(connection).to be_connected
      connection.close
      expect(connection).not_to be_connected
    end
  end

  describe '#connected?' do
    let(:mock_session) { instance_double(Net::SSH::Connection::Session) }

    before do
      allow(Net::SSH).to receive(:start).and_return(mock_session)
    end

    it 'returns false when session is closed' do
      allow(mock_session).to receive(:closed?).and_return(true)
      connection.connect
      expect(connection).not_to be_connected
    end

    it 'returns true when session is open' do
      allow(mock_session).to receive(:closed?).and_return(false)
      connection.connect
      expect(connection).to be_connected
    end
  end
end
