# frozen_string_literal: true

# PatchPilot - A Ruby-based patch management orchestrator
#
# Orchestrates, executes, and confirms patch management across
# heterogeneous Windows and Linux environments.
module PatchPilot
  class Error < StandardError; end

  class << self
    def load_inventory(path = default_inventory_path)
      Inventory.load(path)
    end

    def default_inventory_path
      inventory_path = ENV.fetch('PATCHPILOT_INVENTORY_PATH', nil)
      return inventory_path unless inventory_path.to_s.empty?

      File.expand_path('../config/inventory.yml', __dir__)
    end
  end
end

require_relative 'patch_pilot/credential_resolver'
require_relative 'patch_pilot/connection'
require_relative 'patch_pilot/asset'
require_relative 'patch_pilot/inventory'
require_relative 'patch_pilot/windows/update_query'
require_relative 'patch_pilot/windows/update_executor'
require_relative 'patch_pilot/linux/package_query'
require_relative 'patch_pilot/linux/package_executor'
