# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'
require_relative '../../../lib/patch_pilot/windows/update_executor'

RSpec.describe PatchPilot::Windows::UpdateExecutor do
  let(:connection) { instance_double(PatchPilot::Connections::WinRM) }
  let(:executor) { described_class.new(connection) }

  let(:sample_search_json) do
    <<~JSON.strip
      [{"KBArticleIDs":"5073379","Title":"2026-01 Cumulative Update for Windows 11 (KB5073379)","SizeBytes":524288000,"Severity":"Critical","IsDownloaded":false,"Categories":"Security Updates;Windows 11"},{"KBArticleIDs":"890830","Title":"Windows Malicious Software Removal Tool x64 (KB890830)","SizeBytes":62914560,"Severity":"Unspecified","IsDownloaded":true,"Categories":"Update Rollups"}]
    JSON
  end

  let(:sample_install_json) do
    <<~JSON.strip
      {"ResultCode":2,"RebootRequired":true,"UpdateCount":2,"Updates":[{"KBArticleIDs":"5073379","Title":"2026-01 Cumulative Update (KB5073379)","ResultCode":2},{"KBArticleIDs":"890830","Title":"Malicious Software Removal Tool (KB890830)","ResultCode":2}]}
    JSON
  end

  let(:sample_download_json) do
    <<~JSON.strip
      {"ResultCode":2,"RebootRequired":false,"UpdateCount":2,"Updates":[{"KBArticleIDs":"5073379","Title":"2026-01 Cumulative Update (KB5073379)","ResultCode":2},{"KBArticleIDs":"890830","Title":"Malicious Software Removal Tool (KB890830)","ResultCode":2}]}
    JSON
  end

  let(:empty_action_json) do
    '{"ResultCode":2,"RebootRequired":false,"UpdateCount":0,"Updates":[]}'
  end

  def result(stdout:, stderr: '', exit_code: 0)
    PatchPilot::Connection::Result.new(stdout: stdout, stderr: stderr, exit_code: exit_code)
  end

  describe '#initialize' do
    it 'stores the connection' do
      expect(executor.connection).to eq(connection)
    end
  end

  describe '#available_updates' do
    before do
      allow(connection).to receive(:execute).and_return(result(stdout: sample_search_json))
    end

    it 'returns array of AvailableUpdate objects' do
      updates = executor.available_updates
      expect(updates).to all(be_a(PatchPilot::Windows::AvailableUpdate))
      expect(updates.size).to eq(2)
    end

    it 'parses KB numbers with KB prefix' do
      updates = executor.available_updates
      expect(updates.map(&:kb_number)).to eq(%w[KB5073379 KB890830])
    end

    it 'parses titles correctly' do
      updates = executor.available_updates
      expect(updates[0].title).to eq('2026-01 Cumulative Update for Windows 11 (KB5073379)')
      expect(updates[1].title).to eq('Windows Malicious Software Removal Tool x64 (KB890830)')
    end

    it 'parses size_bytes correctly' do
      updates = executor.available_updates
      expect(updates[0].size_bytes).to eq(524_288_000)
      expect(updates[1].size_bytes).to eq(62_914_560)
    end

    it 'parses severity correctly' do
      updates = executor.available_updates
      expect(updates[0].severity).to eq('Critical')
      expect(updates[1].severity).to eq('Unspecified')
    end

    it 'parses is_downloaded correctly' do
      updates = executor.available_updates
      expect(updates[0].is_downloaded).to be false
      expect(updates[1].is_downloaded).to be true
    end

    it 'parses categories as array' do
      updates = executor.available_updates
      expect(updates[0].categories).to eq(['Security Updates', 'Windows 11'])
      expect(updates[1].categories).to eq(['Update Rollups'])
    end

    it 'caches results' do
      executor.available_updates
      executor.available_updates
      expect(connection).to have_received(:execute).once
    end

    it 'refreshes when requested' do
      executor.available_updates
      executor.available_updates(refresh: true)
      expect(connection).to have_received(:execute).twice
    end

    context 'with empty result' do
      before do
        allow(connection).to receive(:execute).and_return(result(stdout: '[]'))
      end

      it 'returns empty array' do
        expect(executor.available_updates).to eq([])
      end
    end

    context 'with single update (JSON object instead of array)' do
      let(:single_json) do
        { KBArticleIDs: '5073379', Title: 'Update', SizeBytes: 100,
          Severity: 'Critical', IsDownloaded: false,
          Categories: 'Security Updates' }.to_json
      end

      before do
        allow(connection).to receive(:execute).and_return(result(stdout: single_json))
      end

      it 'wraps single object in array' do
        updates = executor.available_updates
        expect(updates.size).to eq(1)
        expect(updates[0].kb_number).to eq('KB5073379')
      end
    end

    context 'when command fails' do
      before do
        allow(connection).to receive(:execute)
          .and_return(result(stdout: '', stderr: 'Access denied', exit_code: 1))
      end

      it 'raises Connection::CommandError' do
        expect { executor.available_updates }
          .to raise_error(PatchPilot::Connection::CommandError, /update search failed/)
      end
    end

    context 'when search returns an error in result JSON' do
      before do
        allow(connection).to receive(:execute)
          .and_return(result(stdout: '{"Error":"Access is denied."}'))
      end

      it 'raises Connection::CommandError with the error message' do
        expect { executor.available_updates }
          .to raise_error(PatchPilot::Connection::CommandError, /WU search failed.*Access is denied/)
      end
    end
  end

  describe '#download_updates' do
    before do
      allow(connection).to receive(:execute).and_return(result(stdout: sample_download_json))
    end

    it 'returns InstallationResult' do
      dl_result = executor.download_updates
      expect(dl_result).to be_a(PatchPilot::Windows::InstallationResult)
    end

    it 'reports succeeded? as true for result code 2' do
      expect(executor.download_updates).to be_succeeded
    end

    it 'reports reboot_required? as false for downloads' do
      expect(executor.download_updates).not_to be_reboot_required
    end

    it 'includes per-update results' do
      dl_result = executor.download_updates
      expect(dl_result.updates.size).to eq(2)
      expect(dl_result.updates.map(&:kb_number)).to eq(%w[KB5073379 KB890830])
      expect(dl_result.updates).to all(be_succeeded)
    end

    it 'includes result_text' do
      dl_result = executor.download_updates
      expect(dl_result.result_text).to eq('Succeeded')
    end

    it 'passes kb_numbers filter to script' do
      executor.download_updates(kb_numbers: %w[KB5073379])
      expect(connection).to have_received(:execute).with(a_string_including("'5073379'"))
    end

    context 'with no available updates' do
      before do
        allow(connection).to receive(:execute).and_return(result(stdout: empty_action_json))
      end

      it 'returns result with update_count 0' do
        dl_result = executor.download_updates
        expect(dl_result.update_count).to eq(0)
        expect(dl_result.updates).to eq([])
        expect(dl_result).to be_succeeded
      end
    end

    context 'when command fails' do
      before do
        allow(connection).to receive(:execute)
          .and_return(result(stdout: '', stderr: 'error', exit_code: 1))
      end

      it 'raises Connection::CommandError' do
        expect { executor.download_updates }
          .to raise_error(PatchPilot::Connection::CommandError, /download failed/)
      end
    end
  end

  describe '#install_updates' do
    before do
      allow(connection).to receive(:execute).and_return(result(stdout: sample_install_json))
    end

    it 'returns InstallationResult' do
      inst_result = executor.install_updates
      expect(inst_result).to be_a(PatchPilot::Windows::InstallationResult)
    end

    it 'reports reboot_required? as true' do
      expect(executor.install_updates).to be_reboot_required
    end

    it 'reports succeeded? as true for result code 2' do
      expect(executor.install_updates).to be_succeeded
    end

    it 'includes per-update results with result_text' do
      inst_result = executor.install_updates
      expect(inst_result.updates.size).to eq(2)
      expect(inst_result.updates.first.result_text).to eq('Succeeded')
    end

    it 'reports update_count' do
      expect(executor.install_updates.update_count).to eq(2)
    end

    it 'includes install block in script' do
      executor.install_updates
      expect(connection).to have_received(:execute).with(a_string_including('$Installer.Install()'))
    end

    it 'passes kb_numbers filter to script' do
      executor.install_updates(kb_numbers: %w[KB5073379 KB890830])
      expect(connection).to have_received(:execute)
        .with(a_string_including("'5073379'").and(including("'890830'")))
    end

    context 'with partial success (code 3)' do
      let(:partial_json) do
        { ResultCode: 3, RebootRequired: true, UpdateCount: 1,
          Updates: [{ KBArticleIDs: '5073379', Title: 'Update',
                      ResultCode: 2 }] }.to_json
      end

      before do
        allow(connection).to receive(:execute).and_return(result(stdout: partial_json))
      end

      it 'reports succeeded? as true' do
        inst_result = executor.install_updates
        expect(inst_result).to be_succeeded
        expect(inst_result.result_text).to eq('SucceededWithErrors')
      end
    end

    context 'with failure (code 4)' do
      let(:failed_json) do
        { ResultCode: 4, RebootRequired: false, UpdateCount: 1,
          Updates: [{ KBArticleIDs: '5073379', Title: 'Update',
                      ResultCode: 4 }] }.to_json
      end

      before do
        allow(connection).to receive(:execute).and_return(result(stdout: failed_json))
      end

      it 'reports succeeded? as false' do
        inst_result = executor.install_updates
        expect(inst_result).not_to be_succeeded
        expect(inst_result.result_text).to eq('Failed')
      end
    end

    context 'when command fails' do
      before do
        allow(connection).to receive(:execute)
          .and_return(result(stdout: '', stderr: 'error', exit_code: 1))
      end

      it 'raises Connection::CommandError' do
        expect { executor.install_updates }
          .to raise_error(PatchPilot::Connection::CommandError, /install failed/)
      end
    end
  end

  describe '#reboot_required?' do
    it 'returns true when reboot is pending' do
      allow(connection).to receive(:execute).and_return(result(stdout: "True\n"))
      expect(executor.reboot_required?).to be true
    end

    it 'returns false when no reboot needed' do
      allow(connection).to receive(:execute).and_return(result(stdout: "False\n"))
      expect(executor.reboot_required?).to be false
    end

    it 'checks registry keys in the script' do
      allow(connection).to receive(:execute).and_return(result(stdout: "False\n"))
      executor.reboot_required?
      expect(connection).to have_received(:execute).with(a_string_including('RebootPending'))
    end

    context 'when command fails' do
      before do
        allow(connection).to receive(:execute)
          .and_return(result(stdout: '', stderr: 'error', exit_code: 1))
      end

      it 'raises Connection::CommandError' do
        expect { executor.reboot_required? }
          .to raise_error(PatchPilot::Connection::CommandError, /reboot check failed/)
      end
    end
  end

  describe '#reboot' do
    it 'executes Restart-Computer -Force' do
      cmd_result = result(stdout: '')
      allow(connection).to receive(:execute)
        .with('Restart-Computer -Force')
        .and_return(cmd_result)
      expect(executor.reboot).to eq(cmd_result)
    end

    context 'when command fails' do
      before do
        allow(connection).to receive(:execute)
          .and_return(result(stdout: '', stderr: 'Access denied', exit_code: 1))
      end

      it 'raises Connection::CommandError' do
        expect { executor.reboot }
          .to raise_error(PatchPilot::Connection::CommandError, /reboot failed/)
      end
    end
  end
end

RSpec.describe PatchPilot::Windows::AvailableUpdate do
  let(:security_update) do
    described_class.new(
      kb_number: 'KB5073379', title: 'Cumulative Update',
      size_bytes: 524_288_000, severity: 'Critical',
      is_downloaded: false, categories: ['Security Updates', 'Windows 11']
    )
  end

  let(:non_security_update) do
    described_class.new(
      kb_number: 'KB890830', title: 'Removal Tool',
      size_bytes: 62_914_560, severity: 'Unspecified',
      is_downloaded: true, categories: ['Update Rollups']
    )
  end

  describe '#downloaded?' do
    it 'returns false when not downloaded' do
      expect(security_update).not_to be_downloaded
    end

    it 'returns true when downloaded' do
      expect(non_security_update).to be_downloaded
    end
  end

  describe '#security?' do
    it 'returns true for Critical severity' do
      expect(security_update).to be_security
    end

    it 'returns false for Unspecified severity' do
      expect(non_security_update).not_to be_security
    end

    it 'returns false when severity is nil' do
      update = described_class.new(severity: nil)
      expect(update).not_to be_security
    end
  end

  describe '#size_mb' do
    it 'converts bytes to megabytes' do
      expect(security_update.size_mb).to eq(500.0)
    end

    it 'returns nil when size_bytes is nil' do
      update = described_class.new(size_bytes: nil)
      expect(update.size_mb).to be_nil
    end
  end
end

RSpec.describe PatchPilot::Windows::InstallationResult do
  describe '#succeeded?' do
    it 'returns true for result code 2' do
      result = described_class.new(result_code: 2)
      expect(result).to be_succeeded
    end

    it 'returns true for result code 3' do
      result = described_class.new(result_code: 3)
      expect(result).to be_succeeded
    end

    it 'returns false for result code 4' do
      result = described_class.new(result_code: 4)
      expect(result).not_to be_succeeded
    end

    it 'returns false for result code 5' do
      result = described_class.new(result_code: 5)
      expect(result).not_to be_succeeded
    end
  end

  describe '#reboot_required?' do
    it 'returns true when reboot is required' do
      result = described_class.new(reboot_required: true)
      expect(result).to be_reboot_required
    end

    it 'returns false when reboot is not required' do
      result = described_class.new(reboot_required: false)
      expect(result).not_to be_reboot_required
    end
  end
end

RSpec.describe PatchPilot::Windows::UpdateActionResult do
  describe '#succeeded?' do
    it 'returns true for result code 2' do
      result = described_class.new(result_code: 2)
      expect(result).to be_succeeded
    end

    it 'returns false for result code 4' do
      result = described_class.new(result_code: 4)
      expect(result).not_to be_succeeded
    end

    it 'returns false for result code 5' do
      result = described_class.new(result_code: 5)
      expect(result).not_to be_succeeded
    end
  end
end
