# frozen_string_literal: true

# PatchPilot - A Ruby-based patch management orchestrator
#
# Orchestrates, executes, and confirms patch management across
# heterogeneous Windows and Linux environments.
module PatchPilot
  class Error < StandardError; end
end

require_relative 'patch_pilot/credential_resolver'
require_relative 'patch_pilot/connection'
require_relative 'patch_pilot/asset'
require_relative 'patch_pilot/inventory'
require_relative 'patch_pilot/windows/update_query'
require_relative 'patch_pilot/linux/package_query'

module PatchPilot # rubocop:disable Style/Documentation
  class << self
    # Load inventory from the default or specified path
    #
    # @param path [String] path to inventory YAML file
    # @return [Inventory] loaded inventory instance
    def load_inventory(path = default_inventory_path)
      Inventory.load(path)
    end

    # Default path to inventory configuration
    #
    # @return [String] path to default inventory file
    def default_inventory_path
      File.expand_path('../config/inventory.yml', __dir__)
    end
  end
end
