# frozen_string_literal: true

require 'csv'
require 'date'

module PatchPilot
  module Windows
    # Represents a single Windows update (hotfix)
    Update = Struct.new(:kb_number, :description, :installed_on, :installed_by, keyword_init: true) do
      # Check if this is a security update
      #
      # @return [Boolean]
      def security_update?
        description&.downcase&.include?('security')
      end

      # Check if KB number matches a pattern
      #
      # @param pattern [String, Regexp] pattern to match against KB number
      # @return [Boolean]
      def matches_kb?(pattern)
        case pattern
        when Regexp
          kb_number&.match?(pattern)
        else
          kb_number&.include?(pattern.to_s)
        end
      end
    end

    # Query Windows Update history via Get-HotFix PowerShell cmdlet.
    # Parses results into structured Update objects for analysis.
    class UpdateQuery
      POWERSHELL_COMMAND = 'Get-HotFix | Select-Object HotFixID, Description, InstalledOn, InstalledBy | ' \
                           'ConvertTo-Csv -NoTypeInformation'

      attr_reader :connection

      # Initialize with an established connection
      #
      # @param connection [Connections::WinRM] an active WinRM connection
      def initialize(connection)
        @connection = connection
        @installed_updates = nil
      end

      # Fetch all installed updates from the remote system
      #
      # @param refresh [Boolean] force refresh even if already cached
      # @return [Array<Update>] list of installed updates
      # @raise [Connection::CommandError] if query fails
      def installed_updates(refresh: false)
        @installed_updates = nil if refresh
        @installed_updates ||= fetch_updates
      end

      # Filter updates by date range
      #
      # @param start_date [Date, nil] earliest installation date (inclusive)
      # @param end_date [Date, nil] latest installation date (inclusive)
      # @return [Array<Update>] filtered updates
      def updates_between(start_date: nil, end_date: nil)
        installed_updates.select do |update|
          next false if update.installed_on.nil?

          after_start = start_date.nil? || update.installed_on >= start_date
          before_end = end_date.nil? || update.installed_on <= end_date
          after_start && before_end
        end
      end

      # Filter updates by KB pattern
      #
      # @param pattern [String, Regexp] pattern to match against KB numbers
      # @return [Array<Update>] matching updates
      def updates_matching(pattern)
        installed_updates.select { |update| update.matches_kb?(pattern) }
      end

      # Get only security updates
      #
      # @return [Array<Update>] security updates only
      def security_updates
        installed_updates.select(&:security_update?)
      end

      # Get KB numbers as a simple array
      #
      # @return [Array<String>] list of KB numbers
      def kb_numbers
        installed_updates.map(&:kb_number).compact
      end

      # Compare updates with another UpdateQuery instance
      # Useful for comparing Deep Freeze endpoint vs control endpoint
      #
      # @param other [UpdateQuery] another UpdateQuery instance to compare against
      # @return [Hash] comparison results with :common, :only_self, :only_other keys
      def compare_with(other)
        self_kbs = Set.new(kb_numbers)
        other_kbs = Set.new(other.kb_numbers)

        {
          common: (self_kbs & other_kbs).to_a.sort,
          only_self: (self_kbs - other_kbs).to_a.sort,
          only_other: (other_kbs - self_kbs).to_a.sort
        }
      end

      # Generate a summary of installed updates
      #
      # @return [String] human-readable summary
      def summary
        updates = installed_updates
        security = security_updates

        lines = [
          "Total updates: #{updates.count}",
          "Security updates: #{security.count}",
          "Date range: #{date_range_string(updates)}"
        ]
        lines.join("\n")
      end

      private

      def fetch_updates
        result = connection.execute(POWERSHELL_COMMAND)
        parse_csv_output(result.stdout)
      end

      def parse_csv_output(csv_string)
        return [] if csv_string.nil? || csv_string.strip.empty?

        csv = CSV.parse(csv_string.strip, headers: true)
        csv.map { |row| build_update(row) }
      end

      def build_update(row)
        Update.new(
          kb_number: row['HotFixID'],
          description: row['Description'],
          installed_on: parse_date(row['InstalledOn']),
          installed_by: presence(row['InstalledBy'])
        )
      end

      def parse_date(date_string)
        return nil if date_string.nil? || date_string.strip.empty?

        # Windows date format: "1/14/2026 12:00:00 AM"
        DateTime.strptime(date_string.strip, '%m/%d/%Y %I:%M:%S %p').to_date
      rescue ArgumentError
        nil
      end

      def presence(value)
        return nil if value.nil? || value.strip.empty?

        value.strip
      end

      def date_range_string(updates)
        dates = updates.map(&:installed_on).compact.sort
        return 'N/A' if dates.empty?

        "#{dates.first} to #{dates.last}"
      end
    end
  end
end
