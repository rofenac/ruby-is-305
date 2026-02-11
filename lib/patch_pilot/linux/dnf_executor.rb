# frozen_string_literal: true

require_relative 'package_executor'

module PatchPilot
  module Linux
    # Execute package upgrades on DNF-based systems (Fedora, RHEL, CentOS).
    # Uses dnf with -y flag to avoid confirmation prompts.
    class DnfExecutor
      UPGRADE_ALL_COMMAND = 'dnf upgrade -y 2>&1'

      attr_reader :connection

      # Initialize with an established SSH connection
      #
      # @param connection [Connections::SSH] an active SSH connection
      def initialize(connection)
        @connection = connection
      end

      # Upgrade all packages with available updates
      #
      # @return [UpgradeResult] upgrade outcome
      # @raise [Connection::CommandError] if command execution fails
      def upgrade_all
        result = connection.execute(UPGRADE_ALL_COMMAND)
        parse_upgrade_result(result)
      end

      # Upgrade specific packages by name
      #
      # @param packages [Array<String>] package names to upgrade
      # @return [UpgradeResult] upgrade outcome
      # @raise [Connection::CommandError] if command execution fails
      def upgrade_packages(packages:)
        names = packages.join(' ')
        command = "dnf upgrade -y #{names} 2>&1"
        result = connection.execute(command)
        parse_upgrade_result(result)
      end

      # Check if a reboot is required after upgrades
      #
      # @return [Boolean] true if reboot is pending
      # @raise [Connection::CommandError] if check fails
      def reboot_required?
        script = 'if command -v needs-restarting > /dev/null 2>&1; then ' \
                 'needs-restarting -r > /dev/null 2>&1 && echo false || echo true; ' \
                 'else echo false; fi'
        result = connection.execute(script)
        validate_result!(result, 'reboot check')
        result.stdout.strip.downcase == 'true'
      end

      private

      def parse_upgrade_result(result)
        stdout = result.stdout || ''
        stderr = result.stderr || ''
        upgraded_packages = parse_upgraded_packages(stdout)

        UpgradeResult.new(
          success: result.success?,
          upgraded_count: upgraded_packages.size,
          upgraded_packages: upgraded_packages,
          stdout: stdout,
          stderr: stderr
        )
      end

      # rubocop:disable Metrics/MethodLength
      def parse_upgraded_packages(output)
        packages = []
        in_upgrading = false

        output.each_line do |line|
          stripped = line.strip
          if stripped.start_with?('Upgrading:')
            in_upgrading = true
            next
          end

          next unless in_upgrading

          break if stripped.empty? || stripped.start_with?('Installing:', 'Transaction Summary',
                                                           'Removing:', 'Downgrading:')

          name_arch = stripped.split.first
          next unless name_arch

          last_dot = name_arch.rindex('.')
          packages << (last_dot ? name_arch[0...last_dot] : name_arch)
        end

        packages
      end
      # rubocop:enable Metrics/MethodLength

      def validate_result!(result, operation)
        return if result.success?

        raise Connection::CommandError,
              "DNF #{operation} failed (exit code #{result.exit_code}): #{result.stderr}"
      end
    end
  end
end
