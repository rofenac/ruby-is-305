# frozen_string_literal: true

module PatchPilot
  # Represents a managed asset (server, endpoint, or workstation)
  # in the lab environment.
  class Asset
    attr_reader :hostname, :ip, :os, :os_version, :role, :credential_ref, :tags, :attributes

    # Initialize an asset from a hash of attributes
    #
    # @param attrs [Hash] asset attributes from inventory YAML
    def initialize(attrs)
      @hostname = attrs.fetch('hostname')
      @ip = attrs.fetch('ip')
      @os = attrs.fetch('os')
      @os_version = attrs['os_version']
      @role = attrs['role']
      @credential_ref = attrs['credential_ref']
      @tags = attrs.fetch('tags', [])
      @attributes = attrs
    end

    # Check if this is a Windows system
    #
    # @return [Boolean]
    def windows?
      os.start_with?('windows')
    end

    # Check if this is a Linux system
    #
    # @return [Boolean]
    def linux?
      os == 'linux'
    end

    # Check if Deep Freeze is installed and active
    #
    # @return [Boolean]
    def deep_freeze?
      attributes.fetch('deep_freeze', false)
    end

    # Check if this is a Docker host
    #
    # @return [Boolean]
    def docker_host?
      attributes.fetch('docker', false)
    end

    # Get the package manager for Linux systems
    #
    # @return [String, nil] package manager name (apt, dnf) or nil for Windows
    def package_manager
      attributes['package_manager']
    end

    # Create a connection to this asset
    #
    # @param inventory [Inventory] inventory instance for credential lookup
    # @return [Connections::WinRM, Connections::SSH] connection instance
    # @raise [Error] if credential_ref is not set or not found
    def connect(inventory)
      raise Error, "No credential_ref set for asset #{hostname}" unless credential_ref

      creds = inventory.credential(credential_ref)
      raise Error, "Credential not found: #{credential_ref}" unless creds

      Connection.for(self, creds)
    end

    # Check if asset has a specific tag
    #
    # @param tag [String] tag to check for
    # @return [Boolean]
    def tagged?(tag)
      tags.include?(tag)
    end

    # String representation for debugging
    #
    # @return [String]
    def to_s
      "#{hostname} (#{ip}) - #{os}"
    end

    # Detailed inspection output
    #
    # @return [String]
    def inspect
      "#<PatchPilot::Asset #{hostname} #{ip} os=#{os} role=#{role} deep_freeze=#{deep_freeze?}>"
    end
  end
end
