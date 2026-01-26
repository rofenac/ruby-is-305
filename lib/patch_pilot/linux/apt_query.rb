# frozen_string_literal: true

require_relative 'package_query'

module PatchPilot
  module Linux
    # Query package information on APT-based systems (Debian, Ubuntu, Kali).
    # Uses dpkg-query for installed packages and apt for upgradable packages.
    class AptQuery
      INSTALLED_COMMAND = "dpkg-query -W -f='${Package}\\t${Version}\\t${Architecture}\\t${Status}\\n'"
      UPGRADABLE_COMMAND = 'apt list --upgradable 2>/dev/null | tail -n +2'

      attr_reader :connection

      # Initialize with an established connection
      #
      # @param connection [Connections::SSH] an active SSH connection
      def initialize(connection)
        @connection = connection
        @installed_packages = nil
        @upgradable_packages = nil
      end

      # Fetch all installed packages from the remote system
      #
      # @param refresh [Boolean] force refresh even if already cached
      # @return [Array<Package>] list of installed packages
      def installed_packages(refresh: false)
        @installed_packages = nil if refresh
        @installed_packages ||= fetch_installed_packages
      end

      # Fetch packages with available upgrades
      #
      # @param refresh [Boolean] force refresh even if already cached
      # @return [Array<Package>] list of upgradable packages
      def upgradable_packages(refresh: false)
        @upgradable_packages = nil if refresh
        @upgradable_packages ||= fetch_upgradable_packages
      end

      # Filter packages by name pattern
      #
      # @param pattern [String, Regexp] pattern to match against package names
      # @return [Array<Package>] matching packages
      def packages_matching(pattern)
        installed_packages.select { |pkg| pkg.matches_name?(pattern) }
      end

      # Get package names as a simple array
      #
      # @return [Array<String>] list of package names
      def package_names
        installed_packages.map(&:name).compact
      end

      # Compare packages with another query instance
      #
      # @param other [AptQuery, DnfQuery] another query instance to compare against
      # @return [Hash] comparison results with :common, :only_self, :only_other keys
      def compare_with(other)
        self_names = Set.new(package_names)
        other_names = Set.new(other.package_names)

        {
          common: (self_names & other_names).to_a.sort,
          only_self: (self_names - other_names).to_a.sort,
          only_other: (other_names - self_names).to_a.sort
        }
      end

      # Generate a summary of package status
      #
      # @return [String] human-readable summary
      def summary
        installed = installed_packages
        upgradable = upgradable_packages

        [
          "Installed packages: #{installed.count}",
          "Upgradable packages: #{upgradable.count}"
        ].join("\n")
      end

      private

      def fetch_installed_packages
        result = connection.execute(INSTALLED_COMMAND)
        parse_dpkg_output(result.stdout)
      end

      def fetch_upgradable_packages
        result = connection.execute(UPGRADABLE_COMMAND)
        parse_apt_upgradable_output(result.stdout)
      end

      def parse_dpkg_output(output)
        return [] if output.nil? || output.strip.empty?

        output.each_line.filter_map { |line| parse_dpkg_line(line) }
      end

      def parse_dpkg_line(line)
        parts = line.strip.split("\t")
        return if parts.size < 4 || !dpkg_installed?(parts[3])

        Package.new(name: parts[0], version: parts[1], architecture: parts[2], status: 'installed')
      end

      def dpkg_installed?(status_field)
        status_field.split.last == 'installed'
      end

      def parse_apt_upgradable_output(output)
        return [] if output.nil? || output.strip.empty?

        output.each_line.filter_map { |line| parse_apt_upgradable_line(line) }
      end

      def parse_apt_upgradable_line(line)
        match = line.match(%r{^([^/]+)/\S+\s+(\S+)\s+(\S+)})
        return unless match

        Package.new(name: match[1], version: match[2], architecture: match[3], status: 'upgradable')
      end
    end
  end
end
