# frozen_string_literal: true

module PatchPilot
  # Connection module provides a factory for creating remote connections
  # and defines the common interface and exceptions for all connection types.
  module Connection
    # Result of executing a remote command
    Result = Struct.new(:stdout, :stderr, :exit_code, keyword_init: true) do
      def success?
        exit_code.zero?
      end
    end

    # Base error for all connection-related failures
    class Error < PatchPilot::Error; end

    # Raised when authentication fails (bad credentials, expired password, etc.)
    class AuthenticationError < Error; end

    # Raised when connection cannot be established (network, firewall, service not running)
    class ConnectionError < Error; end

    # Raised when a command fails to execute
    class CommandError < Error; end

    # Raised when asset type is not supported for connections
    class UnsupportedAssetError < Error; end

    class << self
      # Factory method to create appropriate connection for an asset
      #
      # @param asset [Asset] the asset to connect to
      # @param credentials [Hash] resolved credential configuration
      # @return [Connections::WinRM, Connections::SSH] connection instance
      # @raise [UnsupportedAssetError] if asset OS type is not supported
      def for(asset, credentials)
        if asset.windows?
          build_winrm_connection(asset, credentials)
        elsif asset.linux?
          build_ssh_connection(asset, credentials)
        else
          raise UnsupportedAssetError, "Unsupported OS type: #{asset.os}"
        end
      end

      private

      def build_winrm_connection(asset, credentials)
        require_relative 'connections/winrm'
        Connections::WinRM.new(
          host: asset.ip,
          username: credentials['username'],
          password: credentials['password'],
          domain: credentials['domain']
        )
      end

      def build_ssh_connection(asset, credentials)
        require_relative 'connections/ssh'
        Connections::SSH.new(
          host: asset.ip,
          username: credentials['username'],
          key_file: credentials['key_file'],
          password: credentials['password']
        )
      end
    end
  end
end
