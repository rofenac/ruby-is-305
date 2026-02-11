# frozen_string_literal: true

require 'json'

module PatchPilot
  module Windows
    # Represents an available (not yet installed) Windows update
    AvailableUpdate = Struct.new(:kb_number, :title, :size_bytes, :severity,
                                 :is_downloaded, :categories, keyword_init: true) do
      # Check if the update has already been downloaded
      #
      # @return [Boolean]
      def downloaded?
        is_downloaded == true
      end

      # Check if this is a security-relevant update
      #
      # @return [Boolean]
      def security?
        !severity.nil? && severity.downcase != 'unspecified'
      end

      # Convert size from bytes to megabytes
      #
      # @return [Float, nil] size in MB rounded to 2 decimals, or nil if unknown
      def size_mb
        return nil unless size_bytes

        (size_bytes / 1_048_576.0).round(2)
      end
    end

    # Represents the per-update result of a download or install action
    UpdateActionResult = Struct.new(:kb_number, :title, :result_code, :result_text,
                                    keyword_init: true) do
      # Check if this individual update action succeeded
      #
      # @return [Boolean]
      def succeeded?
        result_code == 2
      end
    end

    # Represents the overall result of a download or install operation
    InstallationResult = Struct.new(:result_code, :result_text, :reboot_required,
                                    :update_count, :updates, keyword_init: true) do
      # Check if the overall operation succeeded (includes partial success)
      #
      # @return [Boolean]
      def succeeded?
        [2, 3].include?(result_code)
      end

      # Check if a reboot is required after this operation
      #
      # @return [Boolean]
      def reboot_required?
        reboot_required == true
      end
    end

    # Trigger Windows Update search, download, and installation remotely
    # via the Windows Update COM API over WinRM.
    #
    # EULAs are auto-accepted for unattended operation.
    # Reboots are never triggered automatically — call #reboot explicitly.
    #
    # @example Search and install all available updates
    #   executor = UpdateExecutor.new(connection)
    #   available = executor.available_updates
    #   result = executor.install_updates
    #   executor.reboot if result.reboot_required?
    #
    # @example Install specific KBs only
    #   result = executor.install_updates(kb_numbers: ['KB5073379'])
    class UpdateExecutor # rubocop:disable Metrics/ClassLength
      RESULT_CODES = {
        0 => 'NotStarted',
        1 => 'InProgress',
        2 => 'Succeeded',
        3 => 'SucceededWithErrors',
        4 => 'Failed',
        5 => 'Aborted'
      }.freeze

      attr_reader :connection

      # Initialize with an established WinRM connection
      #
      # @param connection [Connections::WinRM] an active WinRM connection
      def initialize(connection)
        @connection = connection
        @available_updates = nil
      end

      # Search for available (not yet installed) updates
      #
      # @param refresh [Boolean] force refresh even if already cached
      # @return [Array<AvailableUpdate>] list of available updates
      # @raise [Connection::CommandError] if the search fails
      def available_updates(refresh: false)
        @available_updates = nil if refresh
        @available_updates ||= fetch_available_updates
      end

      # Download updates without installing them
      #
      # @param kb_numbers [Array<String>, nil] specific KBs to download, or nil for all
      # @return [InstallationResult] download outcome
      # @raise [Connection::CommandError] if the download fails
      def download_updates(kb_numbers: nil)
        execute_update_action(:download, kb_numbers)
      end

      # Download and install updates
      #
      # @param kb_numbers [Array<String>, nil] specific KBs to install, or nil for all
      # @return [InstallationResult] installation outcome
      # @raise [Connection::CommandError] if the installation fails
      def install_updates(kb_numbers: nil)
        execute_update_action(:install, kb_numbers)
      end

      # Check if a reboot is currently pending on the remote system
      #
      # @return [Boolean] true if a reboot is pending
      # @raise [Connection::CommandError] if the check fails
      def reboot_required?
        result = connection.execute(reboot_check_script)
        validate_result!(result, 'reboot check')
        result.stdout.strip.downcase == 'true'
      end

      # Trigger a remote system restart
      #
      # This method never runs automatically. The caller must invoke it explicitly,
      # which is critical for Deep Freeze endpoints where the admin must thaw first.
      #
      # @return [Connection::Result] the raw command result
      # @raise [Connection::CommandError] if the restart command fails
      def reboot
        result = connection.execute('Restart-Computer -Force')
        validate_result!(result, 'reboot')
        result
      end

      private

      def fetch_available_updates
        result = connection.execute(search_script)
        validate_result!(result, 'update search')
        parse_available_updates(result.stdout)
      end

      def execute_update_action(action, kb_numbers)
        result = connection.execute(action_script(action, kb_numbers))
        validate_result!(result, action.to_s)
        parse_installation_result(result.stdout)
      end

      # rubocop:disable Metrics/MethodLength
      def search_script
        <<~PS
          $Session = New-Object -ComObject Microsoft.Update.Session
          $Searcher = $Session.CreateUpdateSearcher()
          $SearchResult = $Searcher.Search("IsInstalled=0")
          $updates = @()
          foreach ($Update in $SearchResult.Updates) {
              if ($Update.EulaAccepted -eq $false) { $Update.AcceptEula() }
              $kbs = @($Update.KBArticleIDs) -join ','
              $cats = @()
              foreach ($cat in $Update.Categories) { $cats += $cat.Name }
              $sev = if ($Update.MsrcSeverity) { $Update.MsrcSeverity } else { 'Unspecified' }
              $updates += [PSCustomObject]@{
                  KBArticleIDs = $kbs
                  Title        = $Update.Title
                  SizeBytes    = $Update.MaxDownloadSize
                  Severity     = $sev
                  IsDownloaded = [bool]$Update.IsDownloaded
                  Categories   = ($cats -join ';')
              }
          }
          if ($updates.Count -eq 0) { Write-Output '[]' }
          else { Write-Output (ConvertTo-Json @($updates) -Compress) }
        PS
      end

      def action_script(action, kb_numbers)
        kb_filter = build_kb_filter(kb_numbers)
        install_block = action == :install ? install_powershell_block : ''

        <<~PS
          $Session = New-Object -ComObject Microsoft.Update.Session
          $Searcher = $Session.CreateUpdateSearcher()
          $SearchResult = $Searcher.Search("IsInstalled=0")
          #{kb_filter}
          $UpdateColl = New-Object -ComObject Microsoft.Update.UpdateColl
          foreach ($Update in $SearchResult.Updates) {
              if ($Update.EulaAccepted -eq $false) { $Update.AcceptEula() }
              $kbs = @($Update.KBArticleIDs)
              $match = $KBFilter.Count -eq 0
              foreach ($kb in $kbs) {
                  if ($KBFilter -contains $kb) { $match = $true; break }
              }
              if ($match) { $UpdateColl.Add($Update) | Out-Null }
          }
          if ($UpdateColl.Count -eq 0) {
              Write-Output '{"ResultCode":2,"RebootRequired":false,"UpdateCount":0,"Updates":[]}'
          } else {
              $Downloader = $Session.CreateUpdateDownloader()
              $Downloader.Updates = $UpdateColl
              $DlResult = $Downloader.Download()
              #{install_block}
              $FinalResult = #{action == :install ? '$InstResult' : '$DlResult'}
              $results = @()
              for ($i = 0; $i -lt $UpdateColl.Count; $i++) {
                  $u = $UpdateColl.Item($i)
                  $r = $FinalResult.GetUpdateResult($i)
                  $results += [PSCustomObject]@{
                      KBArticleIDs = (@($u.KBArticleIDs) -join ',')
                      Title        = $u.Title
                      ResultCode   = [int]$r.ResultCode
                  }
              }
              $out = @{
                  ResultCode     = [int]$FinalResult.ResultCode
                  RebootRequired = [bool]$FinalResult.RebootRequired
                  UpdateCount    = $UpdateColl.Count
                  Updates        = @($results)
              }
              Write-Output (ConvertTo-Json $out -Compress)
          }
        PS
      end
      # rubocop:enable Metrics/MethodLength

      def install_powershell_block
        <<~PS.chomp
          $Installer = $Session.CreateUpdateInstaller()
              $Installer.Updates = $UpdateColl
              $InstResult = $Installer.Install()
        PS
      end

      def build_kb_filter(kb_numbers)
        if kb_numbers.nil? || kb_numbers.empty?
          '$KBFilter = @()'
        else
          bare = kb_numbers.map { |kb| kb.to_s.delete_prefix('KB') }
          items = bare.map { |kb| "'#{kb}'" }.join(', ')
          "$KBFilter = @(#{items})"
        end
      end

      def reboot_check_script
        <<~PS
          $reboot = $false
          $cbsKey = 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\RebootPending'
          $wuKey = 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired'
          if (Test-Path $cbsKey) { $reboot = $true }
          if (Test-Path $wuKey) { $reboot = $true }
          $pfro = Get-ItemProperty 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
          if ($pfro) { $reboot = $true }
          Write-Output $reboot
        PS
      end

      def parse_available_updates(json_string)
        return [] if json_string.nil? || json_string.strip.empty?

        data = JSON.parse(json_string.strip)
        data = [data] unless data.is_a?(Array)
        data.map { |entry| build_available_update(entry) }
      end

      def build_available_update(entry)
        AvailableUpdate.new(
          kb_number: normalize_kb(entry['KBArticleIDs']),
          title: entry['Title'],
          size_bytes: entry['SizeBytes'],
          severity: entry['Severity'],
          is_downloaded: entry['IsDownloaded'],
          categories: entry['Categories']&.split(';')
        )
      end

      def parse_installation_result(json_string)
        data = JSON.parse(json_string.strip)
        updates = (data['Updates'] || []).map { |u| build_update_action_result(u) }
        InstallationResult.new(
          result_code: data['ResultCode'],
          result_text: result_text_for(data['ResultCode']),
          reboot_required: data['RebootRequired'],
          update_count: data['UpdateCount'],
          updates: updates
        )
      end

      def build_update_action_result(entry)
        UpdateActionResult.new(
          kb_number: normalize_kb(entry['KBArticleIDs']),
          title: entry['Title'],
          result_code: entry['ResultCode'],
          result_text: result_text_for(entry['ResultCode'])
        )
      end

      def normalize_kb(raw)
        return nil if raw.nil? || raw.strip.empty?

        kb = raw.strip.split(',').first
        kb.start_with?('KB') ? kb : "KB#{kb}"
      end

      def validate_result!(result, operation)
        return if result.success?

        raise Connection::CommandError,
              "Windows Update #{operation} failed (exit code #{result.exit_code}): #{result.stderr}"
      end

      def result_text_for(code)
        RESULT_CODES.fetch(code, "Unknown (#{code})")
      end
    end
  end
end
