# frozen_string_literal: true

require 'winrm'

module PatchPilot
  module Connections
    # WinRM connection for remote command execution on Windows systems.
    # Uses Windows Remote Management protocol over HTTP/HTTPS.
    class WinRM
      DEFAULT_PORT = 5985

      attr_reader :host, :username, :domain, :port

      # Initialize a new WinRM connection
      #
      # @param host [String] hostname or IP address
      # @param username [String] username for authentication
      # @param password [String] password for authentication
      # @param domain [String, nil] Windows domain (optional)
      # @param port [Integer] WinRM port (default: 5985 for HTTP)
      def initialize(host:, username:, password:, domain: nil, port: DEFAULT_PORT)
        @host = host
        @username = username
        @password = password
        @domain = domain
        @port = port
        @connection = nil
        @shell = nil
      end

      # Establish connection to the remote host
      #
      # @return [self]
      # @raise [Connection::ConnectionError] if connection fails
      # @raise [Connection::AuthenticationError] if authentication fails
      def connect
        @connection = ::WinRM::Connection.new(connection_options)
        @shell = @connection.shell(:powershell)
        self
      rescue ::WinRM::WinRMAuthorizationError => e
        raise Connection::AuthenticationError, "Authentication failed for #{user_at_host}: #{e.message}"
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH => e
        raise Connection::ConnectionError, "Failed to connect to #{host}:#{port}: #{e.message}"
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
        output = @shell.run(command)
        Connection::Result.new(
          stdout: output.stdout,
          stderr: output.stderr,
          exit_code: output.exitcode
        )
      rescue ::WinRM::WinRMError => e
        raise Connection::CommandError, "Command execution failed: #{e.message}"
      end

      # Close the connection and release resources
      #
      # @return [void]
      def close
        @shell&.close
        @shell = nil
        @connection = nil
      end

      # Check if connection is established
      #
      # @return [Boolean]
      def connected?
        !@shell.nil?
      end

      private

      def connection_options
        {
          endpoint: "http://#{host}:#{port}/wsman",
          user: full_username,
          password: @password,
          transport: :negotiate
        }
      end

      def full_username
        domain ? "#{domain}\\#{username}" : username
      end

      def user_at_host
        "#{full_username}@#{host}"
      end

      def ensure_connected
        connect unless connected?
      end
    end
  end
end
