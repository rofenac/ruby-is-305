# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'

RSpec.describe PatchPilot::Windows::UpdateQuery do
  let(:connection) { instance_double(PatchPilot::Connections::WinRM) }
  let(:query) { described_class.new(connection) }

  let(:sample_json_output) do
    [
      { 'KBArticleIDs' => '5066131', 'Description' => 'Update',
        'InstalledOn' => '12/6/2025 12:00:00 AM' },
      { 'KBArticleIDs' => '5073379', 'Description' => 'Security Update',
        'InstalledOn' => '1/14/2026 12:00:00 AM' },
      { 'KBArticleIDs' => '5072725', 'Description' => 'Security Update',
        'InstalledOn' => '1/14/2026 12:00:00 AM' },
      { 'KBArticleIDs' => '5071142', 'Description' => 'Update',
        'InstalledOn' => '12/6/2025 12:00:00 AM' }
    ].to_json
  end

  let(:command_result) do
    PatchPilot::Connection::Result.new(stdout: sample_json_output, stderr: '', exit_code: 0)
  end

  before do
    allow(connection).to receive(:execute).and_return(command_result)
  end

  describe '#installed_updates' do
    it 'returns array of Update objects' do
      updates = query.installed_updates
      expect(updates).to all(be_a(PatchPilot::Windows::Update))
    end

    it 'parses KB numbers correctly' do
      updates = query.installed_updates
      expect(updates.map(&:kb_number)).to eq(%w[KB5066131 KB5073379 KB5072725 KB5071142])
    end

    it 'parses descriptions correctly' do
      updates = query.installed_updates
      expect(updates[0].description).to eq('Update')
      expect(updates[1].description).to eq('Security Update')
    end

    it 'parses installation dates correctly' do
      updates = query.installed_updates
      expect(updates[0].installed_on).to eq(Date.new(2025, 12, 6))
      expect(updates[1].installed_on).to eq(Date.new(2026, 1, 14))
    end

    it 'sets installed_by to nil for COM API results' do
      updates = query.installed_updates
      expect(updates.map(&:installed_by)).to all(be_nil)
    end

    it 'caches results' do
      query.installed_updates
      query.installed_updates
      expect(connection).to have_received(:execute).once
    end

    it 'refreshes when requested' do
      query.installed_updates
      query.installed_updates(refresh: true)
      expect(connection).to have_received(:execute).twice
    end

    context 'with empty output' do
      let(:command_result) do
        PatchPilot::Connection::Result.new(stdout: '', stderr: '', exit_code: 0)
      end

      it 'returns empty array' do
        expect(query.installed_updates).to eq([])
      end
    end

    context 'with empty JSON array' do
      let(:command_result) do
        PatchPilot::Connection::Result.new(stdout: '[]', stderr: '', exit_code: 0)
      end

      it 'returns empty array' do
        expect(query.installed_updates).to eq([])
      end
    end

    context 'with single update (non-array JSON)' do
      let(:command_result) do
        single = { 'KBArticleIDs' => '5073379', 'Description' => 'Security Update',
                   'InstalledOn' => '1/14/2026 12:00:00 AM' }.to_json
        PatchPilot::Connection::Result.new(stdout: single, stderr: '', exit_code: 0)
      end

      it 'wraps single result in array' do
        updates = query.installed_updates
        expect(updates.size).to eq(1)
        expect(updates.first.kb_number).to eq('KB5073379')
      end
    end
  end

  describe '#updates_between' do
    it 'filters by start date' do
      updates = query.updates_between(start_date: Date.new(2026, 1, 1))
      expect(updates.count).to eq(2)
      expect(updates.map(&:kb_number)).to contain_exactly('KB5073379', 'KB5072725')
    end

    it 'filters by end date' do
      updates = query.updates_between(end_date: Date.new(2025, 12, 31))
      expect(updates.count).to eq(2)
      expect(updates.map(&:kb_number)).to contain_exactly('KB5066131', 'KB5071142')
    end

    it 'filters by date range' do
      updates = query.updates_between(start_date: Date.new(2025, 12, 1), end_date: Date.new(2025, 12, 31))
      expect(updates.count).to eq(2)
    end
  end

  describe '#updates_matching' do
    it 'filters by KB string pattern' do
      updates = query.updates_matching('KB507')
      expect(updates.count).to eq(3)
    end

    it 'filters by regex pattern' do
      updates = query.updates_matching(/KB50[67]/)
      expect(updates.count).to eq(4)
    end
  end

  describe '#security_updates' do
    it 'returns only security updates' do
      security = query.security_updates
      expect(security.count).to eq(2)
      expect(security.map(&:kb_number)).to contain_exactly('KB5073379', 'KB5072725')
    end
  end

  describe '#kb_numbers' do
    it 'returns array of KB numbers' do
      expect(query.kb_numbers).to eq(%w[KB5066131 KB5073379 KB5072725 KB5071142])
    end
  end

  describe '#compare_with' do
    let(:other_connection) { instance_double(PatchPilot::Connections::WinRM) }
    let(:other_query) { described_class.new(other_connection) }

    let(:other_json_output) do
      [
        { 'KBArticleIDs' => '5066131', 'Description' => 'Update',
          'InstalledOn' => '12/6/2025 12:00:00 AM' },
        { 'KBArticleIDs' => '5073379', 'Description' => 'Security Update',
          'InstalledOn' => '1/14/2026 12:00:00 AM' },
        { 'KBArticleIDs' => '9999999', 'Description' => 'Update',
          'InstalledOn' => '1/20/2026 12:00:00 AM' }
      ].to_json
    end

    before do
      other_result = PatchPilot::Connection::Result.new(stdout: other_json_output, stderr: '', exit_code: 0)
      allow(other_connection).to receive(:execute).and_return(other_result)
    end

    it 'identifies common updates' do
      comparison = query.compare_with(other_query)
      expect(comparison[:common]).to contain_exactly('KB5066131', 'KB5073379')
    end

    it 'identifies updates only in self' do
      comparison = query.compare_with(other_query)
      expect(comparison[:only_self]).to contain_exactly('KB5072725', 'KB5071142')
    end

    it 'identifies updates only in other' do
      comparison = query.compare_with(other_query)
      expect(comparison[:only_other]).to contain_exactly('KB9999999')
    end
  end

  describe '#summary' do
    it 'returns formatted summary' do
      summary = query.summary
      expect(summary).to include('Total updates: 4')
      expect(summary).to include('Security updates: 2')
      expect(summary).to include('Date range:')
    end
  end
end

RSpec.describe PatchPilot::Windows::Update do
  let(:security_update) do
    described_class.new(
      kb_number: 'KB5073379',
      description: 'Security Update',
      installed_on: Date.new(2026, 1, 14),
      installed_by: nil
    )
  end

  let(:regular_update) do
    described_class.new(
      kb_number: 'KB5066131',
      description: 'Update',
      installed_on: Date.new(2025, 12, 6),
      installed_by: nil
    )
  end

  describe '#security_update?' do
    it 'returns true for security updates' do
      expect(security_update.security_update?).to be true
    end

    it 'returns false for regular updates' do
      expect(regular_update.security_update?).to be false
    end
  end

  describe '#matches_kb?' do
    it 'matches string pattern' do
      expect(security_update.matches_kb?('KB507')).to be true
      expect(security_update.matches_kb?('KB999')).to be false
    end

    it 'matches regex pattern' do
      expect(security_update.matches_kb?(/KB\d{7}/)).to be true
      expect(security_update.matches_kb?(/KB999/)).to be false
    end
  end
end
