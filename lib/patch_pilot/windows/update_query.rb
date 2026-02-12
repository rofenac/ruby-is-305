# frozen_string_literal: true

require 'json'
require 'date'

module PatchPilot
  module Windows
    # Represents a single installed Windows update
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

    # Query installed Windows Updates via the Windows Update COM API.
    # Uses IUpdateSearcher.Search("IsInstalled=1") which returns the complete
    # set of installed updates — unlike Get-HotFix which only returns CBS hotfixes.
    class UpdateQuery # rubocop:disable Metrics/ClassLength
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

      def query_script
        <<~PS
          $seen = @{}
          $updates = @()
          foreach ($hf in (Get-HotFix)) {
              $kb = $hf.HotFixID
              if ([string]::IsNullOrEmpty($kb) -or $kb -eq 'File 1') { continue }
              $kbNum = $kb -replace '^KB', ''
              if ($seen.ContainsKey($kbNum)) { continue }
              $seen[$kbNum] = $true
              $desc = if ($hf.Description -match 'Security') { 'Security Update' }
                      else { $hf.Description }
              $date = if ($hf.InstalledOn) {
                          $hf.InstalledOn.ToString('M/d/yyyy h:mm:ss tt')
                      } else { '' }
              $updates += [PSCustomObject]@{
                  KBArticleIDs = $kbNum
                  Description  = $desc
                  InstalledOn  = $date
              }
          }
          $Session = New-Object -ComObject Microsoft.Update.Session
          $Searcher = $Session.CreateUpdateSearcher()
          $HistoryCount = $Searcher.GetTotalHistoryCount()
          if ($HistoryCount -gt 0) {
              $History = $Searcher.QueryHistory(0, $HistoryCount)
              for ($i = 0; $i -lt $History.Count; $i++) {
                  $Entry = $History.Item($i)
                  if ($Entry.Operation -ne 1) { continue }
                  if ($Entry.ResultCode -ne 2 -and $Entry.ResultCode -ne 3) { continue }
                  $kb = ''
                  if ($Entry.Title -match '\\(KB(\\d+)\\)') { $kb = $Matches[1] }
                  if ([string]::IsNullOrEmpty($kb)) { continue }
                  if ($seen.ContainsKey($kb)) { continue }
                  $seen[$kb] = $true
                  $desc = if ($Entry.Title -match 'Security|Malicious') { 'Security Update' }
                          else { 'Update' }
                  $updates += [PSCustomObject]@{
                      KBArticleIDs = $kb
                      Description  = $desc
                      InstalledOn  = $Entry.Date.ToString('M/d/yyyy h:mm:ss tt')
                  }
              }
          }
          if ($updates.Count -eq 0) { Write-Output '[]' }
          else { Write-Output (ConvertTo-Json @($updates) -Compress) }
        PS
      end

      def fetch_updates
        result = connection.execute(query_script)
        parse_json_output(result.stdout)
      end

      def parse_json_output(json_string)
        return [] if json_string.nil? || json_string.strip.empty?

        data = JSON.parse(json_string.strip)
        data = [data] unless data.is_a?(Array)
        data.map { |entry| build_update(entry) }
      end

      def build_update(entry)
        Update.new(
          kb_number: normalize_kb(entry['KBArticleIDs']),
          description: entry['Description'],
          installed_on: parse_date(entry['InstalledOn']),
          installed_by: nil
        )
      end

      def normalize_kb(raw)
        return nil if raw.nil? || raw.to_s.strip.empty?

        kb = raw.strip.split(',').first
        kb.start_with?('KB') ? kb : "KB#{kb}"
      end

      def parse_date(date_string)
        return nil if date_string.nil? || date_string.strip.empty?

        DateTime.strptime(date_string.strip, '%m/%d/%Y %I:%M:%S %p').to_date
      rescue ArgumentError
        nil
      end

      def date_range_string(updates)
        dates = updates.map(&:installed_on).compact.sort
        return 'N/A' if dates.empty?

        "#{dates.first} to #{dates.last}"
      end
    end
  end
end
