# frozen_string_literal: true

require 'net/ssh'

module PatchPilot
  module Connections
    # SSH connection for remote command execution on Linux systems.
    # Supports both key-based and password authentication.
    class SSH
      DEFAULT_PORT = 22

      attr_reader :host, :username, :key_file, :port

      # Initialize a new SSH connection
      #
      # @param host [String] hostname or IP address
      # @param username [String] username for authentication
      # @param key_file [String, nil] path to SSH private key (optional)
      # @param password [String, nil] password for authentication (optional)
      # @param port [Integer] SSH port (default: 22)
      def initialize(host:, username:, key_file: nil, password: nil, port: DEFAULT_PORT)
        @host = host
        @username = username
        @key_file = expand_key_file(key_file)
        @password = password
        @port = port
        @session = nil
      end

      # Establish connection to the remote host
      #
      # @return [self]
      # @raise [Connection::ConnectionError] if connection fails
      # @raise [Connection::AuthenticationError] if authentication fails
      def connect
        @session = Net::SSH.start(host, username, connection_options)
        self
      rescue Net::SSH::AuthenticationFailed => e
        raise Connection::AuthenticationError, "Authentication failed for #{username}@#{host}: #{e.message}"
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH, SocketError => e
        raise Connection::ConnectionError, wrap_connection_error(e)
      rescue StandardError => e
        raise Connection::ConnectionError, "Connection error for #{host}: #{e.message}"
      end

      # Execute a command on the remote host
      #
      # @param command [String] command to execute
      # @return [Connection::Result] execution result with stdout, stderr, exit_code
      # @raise [Connection::CommandError] if command execution fails
      def execute(command)
        ensure_connected
        output = run_command(command)
        Connection::Result.new(stdout: output[:stdout], stderr: output[:stderr], exit_code: output[:exit_code] || 0)
      rescue Net::SSH::Exception => e
        raise Connection::CommandError, "Command execution failed: #{e.message}"
      end

      # Close the connection and release resources
      #
      # @return [void]
      def close
        @session&.close
        @session = nil
      end

      # Check if connection is established
      #
      # @return [Boolean]
      def connected?
        @session && !@session.closed?
      end

      private

      def connection_options
        {
          port: port,
          non_interactive: true,
          timeout: 10 # Connection timeout in seconds
        }.merge(auth_options)
      end

      def auth_options
        if key_file && File.exist?(key_file)
          { keys: [key_file], keys_only: true }
        elsif @password
          { password: @password }
        else
          {}
        end
      end

      def expand_key_file(path)
        return nil if path.nil?

        File.expand_path(path)
      end

      def ensure_connected
        connect unless connected?
      end

      def wrap_connection_error(error)
        case error
        when SocketError
          "DNS resolution failed for #{host}: #{error.message}"
        else
          "Failed to connect to #{host}:#{port}: #{error.message}"
        end
      end

      def run_command(command)
        output = { stdout: +'', stderr: +'', exit_code: nil }
        @session.open_channel { |ch| setup_channel(ch, command, output) }
        @session.loop
        output
      end

      def setup_channel(channel, command, output)
        channel.exec(command) do |_, success|
          raise Connection::CommandError, "Failed to execute command: #{command}" unless success

          channel.on_data { |_, data| output[:stdout] << data }
          channel.on_extended_data { |_, _, data| output[:stderr] << data }
          channel.on_request('exit-status') { |_, data| output[:exit_code] = data.read_long }
        end
      end
    end
  end
end
