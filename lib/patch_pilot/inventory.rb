# frozen_string_literal: true

require 'yaml'

module PatchPilot
  # Manages the collection of assets loaded from inventory configuration.
  # Provides filtering and querying capabilities.
  class Inventory
    attr_reader :assets, :credentials

    # Load inventory from a YAML file
    #
    # @param path [String] path to inventory YAML file
    # @return [Inventory] new inventory instance
    # @raise [Error] if file cannot be loaded or parsed
    def self.load(path)
      raise Error, "Inventory file not found: #{path}" unless File.exist?(path)

      data = YAML.safe_load_file(path, permitted_classes: [], permitted_symbols: [], aliases: true)
      new(data)
    rescue Psych::SyntaxError => e
      raise Error, "Invalid YAML in inventory file: #{e.message}"
    end

    # Initialize inventory from parsed YAML data
    #
    # @param data [Hash] parsed YAML data
    def initialize(data)
      @credentials = data.fetch('credentials', {})
      @assets = data.fetch('assets', []).map { |attrs| Asset.new(attrs) }
    end

    # Get all Windows assets
    #
    # @return [Array<Asset>]
    def windows
      assets.select(&:windows?)
    end

    # Get all Linux assets
    #
    # @return [Array<Asset>]
    def linux
      assets.select(&:linux?)
    end

    # Get all assets with Deep Freeze enabled
    #
    # @return [Array<Asset>]
    def deep_freeze_enabled
      assets.select(&:deep_freeze?)
    end

    # Get all control assets (Windows without Deep Freeze)
    #
    # @return [Array<Asset>]
    def control_endpoints
      windows.reject(&:deep_freeze?).select { |a| a.role == 'endpoint' }
    end

    # Get all Docker hosts
    #
    # @return [Array<Asset>]
    def docker_hosts
      assets.select(&:docker_host?)
    end

    # Find assets by tag
    #
    # @param tag [String] tag to filter by
    # @return [Array<Asset>]
    def by_tag(tag)
      assets.select { |a| a.tagged?(tag) }
    end

    # Find assets by role
    #
    # @param role [String] role to filter by
    # @return [Array<Asset>]
    def by_role(role)
      assets.select { |a| a.role == role }
    end

    # Find a single asset by hostname
    #
    # @param hostname [String] hostname to find
    # @return [Asset, nil]
    def find(hostname)
      assets.find { |a| a.hostname == hostname }
    end

    # Get credential configuration by reference name with environment variables resolved
    #
    # @param ref [String] credential reference name
    # @return [Hash, nil] resolved credential hash or nil if not found
    # @raise [Error] if referenced environment variable is not set
    def credential(ref)
      cred = credentials[ref]
      return nil unless cred

      CredentialResolver.resolve(cred)
    end

    # Total count of assets
    #
    # @return [Integer]
    def count
      assets.count
    end

    # Iterate over all assets
    #
    # @yield [Asset] each asset
    def each(&)
      assets.each(&)
    end

    # Summary of inventory contents
    #
    # @return [String]
    def summary
      <<~SUMMARY
        Inventory Summary:
          Total assets: #{count}
          Windows: #{windows.count}
          Linux: #{linux.count}
          Deep Freeze enabled: #{deep_freeze_enabled.count}
          Control endpoints: #{control_endpoints.count}
          Docker hosts: #{docker_hosts.count}
      SUMMARY
    end
  end
end
