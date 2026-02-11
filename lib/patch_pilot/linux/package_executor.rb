# frozen_string_literal: true

module PatchPilot
  module Linux
    # Represents the result of a package upgrade operation
    UpgradeResult = Struct.new(:success, :upgraded_count, :upgraded_packages,
                               :stdout, :stderr, keyword_init: true) do
      # Check if the upgrade completed successfully
      #
      # @return [Boolean]
      def succeeded?
        success == true
      end
    end

    # Factory module for creating package executor instances based on package manager type
    module PackageExecutor
      # Create appropriate executor instance for the given package manager
      #
      # @param connection [Connections::SSH] an active SSH connection
      # @param package_manager [String, Symbol] the package manager type ('apt' or 'dnf')
      # @return [AptExecutor, DnfExecutor] executor instance for the specified package manager
      # @raise [PatchPilot::Error] if package manager is not supported
      def self.for(connection, package_manager:)
        case package_manager.to_s
        when 'apt' then AptExecutor.new(connection)
        when 'dnf' then DnfExecutor.new(connection)
        else raise PatchPilot::Error, "Unknown package manager: #{package_manager}"
        end
      end
    end
  end
end

require_relative 'apt_executor'
require_relative 'dnf_executor'
