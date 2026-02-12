# frozen_string_literal: true

require 'socket'
require 'winrm'

module PatchPilot
  module Connections
    # WinRM connection for remote command execution on Windows systems.
    # Uses Windows Remote Management protocol over HTTP/HTTPS.
    class WinRM # rubocop:disable Metrics/ClassLength
      CONNECT_TIMEOUT = 10
      DEFAULT_PORT = 5985
      DEFAULT_OPERATION_TIMEOUT = 60

      attr_reader :host, :username, :domain, :port, :operation_timeout

      # Initialize a new WinRM connection
      #
      # @param host [String] hostname or IP address
      # @param username [String] username for authentication
      # @param password [String] password for authentication
      # @param domain [String, nil] Windows domain (optional)
      # @param port [Integer] WinRM port (default: 5985 for HTTP)
      # @param operation_timeout [Integer] seconds for WinRM commands (default: 60)
      # rubocop:disable Metrics/ParameterLists
      def initialize(host:, username:, password:, domain: nil, port: DEFAULT_PORT,
                     operation_timeout: DEFAULT_OPERATION_TIMEOUT)
        # rubocop:enable Metrics/ParameterLists
        @host = host
        @username = username
        @password = password
        @domain = domain
        @port = port
        @operation_timeout = operation_timeout
        @connection = nil
        @shell = nil
      end

      # Establish connection to the remote host
      #
      # @return [self]
      # @raise [Connection::ConnectionError] if connection fails
      # @raise [Connection::AuthenticationError] if authentication fails
      def connect
        open_shell
        self
      rescue ::WinRM::WinRMAuthorizationError => e
        raise Connection::AuthenticationError, "Authentication failed for #{user_at_host}: #{e.message}"
      rescue Connection::ConnectionError
        raise
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
      # rubocop:disable Metrics/MethodLength
      def execute(command)
        ensure_connected
        output = @shell.run(command)
        Connection::Result.new(
          stdout: output.stdout,
          stderr: output.stderr,
          exit_code: output.exitcode
        )
      rescue ::WinRM::WinRMAuthorizationError => e
        raise Connection::CommandError, winrm_auth_error_message(e)
      rescue ::WinRM::WinRMError => e
        raise Connection::CommandError, "Command execution failed: #{e.message}"
      end
      # rubocop:enable Metrics/MethodLength

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

      def verify_port_reachable
        Socket.tcp(host, port, connect_timeout: CONNECT_TIMEOUT, &:close)
      rescue Errno::ETIMEDOUT, Errno::EHOSTUNREACH
        raise Connection::ConnectionError, "Cannot reach #{host}:#{port} (timed out after #{CONNECT_TIMEOUT}s)"
      rescue Errno::ECONNREFUSED
        raise Connection::ConnectionError,
              "Connection refused at #{host}:#{port} — WinRM may not be enabled. Run: winrm quickconfig"
      end

      def open_shell
        verify_port_reachable
        thread = Thread.new { establish_connection }
        thread.report_on_exception = false
        return thread.value if thread.join(CONNECT_TIMEOUT)

        thread.kill
        raise Connection::ConnectionError,
              "WinRM negotiate timed out for #{host}:#{port} after #{CONNECT_TIMEOUT}s"
      end

      def establish_connection
        @connection = ::WinRM::Connection.new(connection_options)
        @shell = @connection.shell(:powershell)
      end

      def connection_options
        {
          endpoint: "http://#{host}:#{port}/wsman",
          user: full_username,
          password: @password,
          transport: :negotiate,
          open_timeout: 10,
          receive_timeout: @operation_timeout + 10,
          operation_timeout: @operation_timeout
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

      def winrm_auth_error_message(error)
        <<~MSG
          WinRM authorization failed for #{user_at_host}: #{error.message}

          The user can connect but doesn't have permission to execute PowerShell commands.
          To fix this, run these commands on #{host} as Administrator:

          1. Add user to Remote Management Users group:
             net localgroup "Remote Management Users" "#{full_username}" /add

          2. Grant PowerShell remoting permissions:
             Set-PSSessionConfiguration -Name Microsoft.PowerShell -ShowSecurityDescriptorUI

          3. Or, if domain user needs admin rights:
             net localgroup "Administrators" "#{full_username}" /add
        MSG
      end
    end
  end
end
