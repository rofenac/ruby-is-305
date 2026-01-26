# frozen_string_literal: true

require_relative 'package_query'

module PatchPilot
  module Linux
    # Query package information on DNF-based systems (Fedora, RHEL, CentOS).
    # Uses dnf commands to list installed and upgradable packages.
    class DnfQuery
      INSTALLED_COMMAND = 'dnf list installed --quiet 2>/dev/null | tail -n +2'
      UPGRADABLE_COMMAND = 'dnf check-update --quiet 2>/dev/null || true'

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
        parse_dnf_output(result.stdout, 'installed')
      end

      def fetch_upgradable_packages
        result = connection.execute(UPGRADABLE_COMMAND)
        parse_dnf_output(result.stdout, 'upgradable')
      end

      def parse_dnf_output(output, status)
        return [] if output.nil? || output.strip.empty?

        output.each_line.filter_map { |line| parse_dnf_line(line, status) }
      end

      def parse_dnf_line(line, status)
        parts = line.strip.split
        return if parts.empty? || parts.size < 2

        build_package_from_dnf(parts[0], parts[1], status)
      end

      def build_package_from_dnf(name_arch, version, status)
        name, arch = split_name_arch(name_arch)
        return if name.nil?

        Package.new(name: name, version: version, architecture: arch, status: status)
      end

      def split_name_arch(name_arch)
        last_dot = name_arch.rindex('.')
        return nil if last_dot.nil?

        [name_arch[0...last_dot], name_arch[(last_dot + 1)..]]
      end
    end
  end
end
