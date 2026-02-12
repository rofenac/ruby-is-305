# frozen_string_literal: true

require_relative 'package_executor'

module PatchPilot
  module Linux
    # Execute package upgrades on APT-based systems (Debian, Ubuntu, Kali).
    # Uses apt-get with non-interactive mode to avoid confirmation prompts.
    class AptExecutor
      UPGRADE_ALL_COMMAND = 'sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1'
      REBOOT_CHECK_COMMAND = 'test -f /var/run/reboot-required && echo true || echo false'

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
        command = "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade #{names} 2>&1"
        result = connection.execute(command)
        parse_upgrade_result(result)
      end

      # Check if a reboot is required after upgrades
      #
      # @return [Boolean] true if reboot is pending
      # @raise [Connection::CommandError] if check fails
      def reboot_required?
        result = connection.execute(REBOOT_CHECK_COMMAND)
        validate_result!(result, 'reboot check')
        result.stdout.strip.downcase == 'true'
      end

      private

      def parse_upgrade_result(result)
        stdout = result.stdout || ''
        stderr = result.stderr || ''

        UpgradeResult.new(
          success: result.success?,
          upgraded_count: parse_upgraded_count(stdout),
          upgraded_packages: parse_upgraded_packages(stdout),
          stdout: stdout,
          stderr: stderr
        )
      end

      def parse_upgraded_count(output)
        match = output.match(/(\d+)\s+upgraded/)
        match ? match[1].to_i : 0
      end

      def parse_upgraded_packages(output)
        match = output.match(/The following packages will be upgraded:\s*\n(.*?)(?:\n\S|\z)/m)
        return [] unless match

        match[1].strip.split
      end

      def validate_result!(result, operation)
        return if result.success?

        raise Connection::CommandError,
              "APT #{operation} failed (exit code #{result.exit_code}): #{result.stderr}"
      end
    end
  end
end
