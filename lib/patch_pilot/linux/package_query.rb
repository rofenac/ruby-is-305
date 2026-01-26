# frozen_string_literal: true

module PatchPilot
  module Linux
    # Represents a Linux package with its metadata
    Package = Struct.new(:name, :version, :architecture, :status, keyword_init: true) do
      # Check if this package has an upgrade available
      #
      # @return [Boolean]
      def upgradable?
        status == 'upgradable'
      end

      # Check if package name matches a pattern
      #
      # @param pattern [String, Regexp] pattern to match against package name
      # @return [Boolean]
      def matches_name?(pattern)
        return false if name.nil?

        case pattern
        when Regexp then name.match?(pattern)
        else name.include?(pattern.to_s)
        end
      end
    end

    # Factory module for creating package query instances based on package manager type
    module PackageQuery
      # Create appropriate query instance for the given package manager
      #
      # @param connection [Connections::SSH] an active SSH connection
      # @param package_manager [String, Symbol] the package manager type ('apt' or 'dnf')
      # @return [AptQuery, DnfQuery] query instance for the specified package manager
      # @raise [PatchPilot::Error] if package manager is not supported
      def self.for(connection, package_manager:)
        case package_manager.to_s
        when 'apt' then AptQuery.new(connection)
        when 'dnf' then DnfQuery.new(connection)
        else raise PatchPilot::Error, "Unknown package manager: #{package_manager}"
        end
      end
    end
  end
end

require_relative 'apt_query'
require_relative 'dnf_query'
