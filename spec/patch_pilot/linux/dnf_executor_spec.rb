# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'
require_relative '../../../lib/patch_pilot/linux/package_executor'

RSpec.describe PatchPilot::Linux::DnfExecutor do
  let(:connection) { instance_double(PatchPilot::Connections::SSH) }
  let(:executor) { described_class.new(connection) }

  def result(stdout:, stderr: '', exit_code: 0)
    PatchPilot::Connection::Result.new(stdout: stdout, stderr: stderr, exit_code: exit_code)
  end

  let(:sample_upgrade_output) do
    <<~OUTPUT
      Last metadata expiration check: 0:23:45 ago on Mon 10 Feb 2026 10:00:00 AM PST.
      Dependencies resolved.
      ================================================================================
       Package           Arch        Version              Repository            Size
      ================================================================================
      Upgrading:
       vim-enhanced      x86_64      2:9.0.2081-2.fc43    updates              1.7 M
       openssl           x86_64      1:3.0.9-5.fc43       updates              771 k
       curl              x86_64      8.5.0-1.fc43         updates              390 k

      Transaction Summary
      ================================================================================
      Upgrade  3 Packages

      Total download size: 2.9 M
      Downloading Packages:
      Running transaction
      Complete!
    OUTPUT
  end

  let(:no_upgrade_output) do
    <<~OUTPUT
      Last metadata expiration check: 0:23:45 ago on Mon 10 Feb 2026 10:00:00 AM PST.
      Dependencies resolved.
      Nothing to do.
      Complete!
    OUTPUT
  end

  describe '#initialize' do
    it 'stores the connection' do
      expect(executor.connection).to eq(connection)
    end
  end

  describe '#upgrade_all' do
    before do
      allow(connection).to receive(:execute)
        .with(described_class::UPGRADE_ALL_COMMAND)
        .and_return(result(stdout: sample_upgrade_output))
    end

    it 'returns an UpgradeResult' do
      expect(executor.upgrade_all).to be_a(PatchPilot::Linux::UpgradeResult)
    end

    it 'reports success' do
      expect(executor.upgrade_all).to be_succeeded
    end

    it 'parses upgraded count' do
      expect(executor.upgrade_all.upgraded_count).to eq(3)
    end

    it 'parses upgraded package names' do
      expect(executor.upgrade_all.upgraded_packages).to eq(%w[vim-enhanced openssl curl])
    end

    it 'includes raw stdout' do
      expect(executor.upgrade_all.stdout).to include('Complete!')
    end

    context 'with no upgrades available' do
      before do
        allow(connection).to receive(:execute)
          .with(described_class::UPGRADE_ALL_COMMAND)
          .and_return(result(stdout: no_upgrade_output))
      end

      it 'returns zero upgraded count' do
        expect(executor.upgrade_all.upgraded_count).to eq(0)
      end

      it 'returns empty upgraded packages' do
        expect(executor.upgrade_all.upgraded_packages).to eq([])
      end

      it 'still reports success' do
        expect(executor.upgrade_all).to be_succeeded
      end
    end

    context 'when command fails' do
      before do
        allow(connection).to receive(:execute)
          .with(described_class::UPGRADE_ALL_COMMAND)
          .and_return(result(stdout: '', stderr: 'Error: Cannot connect', exit_code: 1))
      end

      it 'reports failure' do
        upgrade_result = executor.upgrade_all
        expect(upgrade_result).not_to be_succeeded
        expect(upgrade_result.stderr).to include('Cannot connect')
      end
    end
  end

  describe '#upgrade_packages' do
    before do
      allow(connection).to receive(:execute)
        .with(a_string_including('dnf upgrade -y vim-enhanced openssl'))
        .and_return(result(stdout: sample_upgrade_output))
    end

    it 'returns an UpgradeResult' do
      upgrade_result = executor.upgrade_packages(packages: %w[vim-enhanced openssl])
      expect(upgrade_result).to be_a(PatchPilot::Linux::UpgradeResult)
    end

    it 'constructs command with package names' do
      executor.upgrade_packages(packages: %w[vim-enhanced openssl])
      expect(connection).to have_received(:execute)
        .with('dnf upgrade -y vim-enhanced openssl 2>&1')
    end
  end

  describe '#reboot_required?' do
    it 'returns true when needs-restarting reports reboot needed' do
      allow(connection).to receive(:execute)
        .and_return(result(stdout: "true\n"))
      expect(executor.reboot_required?).to be true
    end

    it 'returns false when no reboot needed' do
      allow(connection).to receive(:execute)
        .and_return(result(stdout: "false\n"))
      expect(executor.reboot_required?).to be false
    end

    it 'checks for needs-restarting availability' do
      allow(connection).to receive(:execute)
        .and_return(result(stdout: "false\n"))
      executor.reboot_required?
      expect(connection).to have_received(:execute)
        .with(a_string_including('command -v needs-restarting'))
    end

    context 'when command fails' do
      before do
        allow(connection).to receive(:execute)
          .and_return(result(stdout: '', stderr: 'error', exit_code: 1))
      end

      it 'raises Connection::CommandError' do
        expect { executor.reboot_required? }
          .to raise_error(PatchPilot::Connection::CommandError, /DNF reboot check failed/)
      end
    end
  end
end
