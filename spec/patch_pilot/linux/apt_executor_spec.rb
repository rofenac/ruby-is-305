# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'
require_relative '../../../lib/patch_pilot/linux/package_executor'

RSpec.describe PatchPilot::Linux::AptExecutor do
  let(:connection) { instance_double(PatchPilot::Connections::SSH) }
  let(:executor) { described_class.new(connection) }

  def result(stdout:, stderr: '', exit_code: 0)
    PatchPilot::Connection::Result.new(stdout: stdout, stderr: stderr, exit_code: exit_code)
  end

  let(:sample_upgrade_output) do
    <<~OUTPUT
      Reading package lists... Done
      Building dependency tree... Done
      Reading state information... Done
      Calculating upgrade... Done
      The following packages will be upgraded:
        libssl3 openssl vim
      3 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
      Need to get 5,123 kB of archives.
      After this operation, 0 B of additional disk space will be used.
      Get:1 http://archive.ubuntu.com/ubuntu jammy-updates/main amd64 libssl3 amd64 3.0.2-0ubuntu1.18 [1,904 kB]
      Get:2 http://archive.ubuntu.com/ubuntu jammy-updates/main amd64 openssl amd64 3.0.2-0ubuntu1.18 [1,182 kB]
      Get:3 http://archive.ubuntu.com/ubuntu jammy-updates/main amd64 vim amd64 2:9.0.1000-4ubuntu3 [2,037 kB]
      Fetched 5,123 kB in 2s (2,562 kB/s)
      Setting up libssl3:amd64 (3.0.2-0ubuntu1.18) ...
      Setting up openssl (3.0.2-0ubuntu1.18) ...
      Setting up vim (2:9.0.1000-4ubuntu3) ...
    OUTPUT
  end

  let(:no_upgrade_output) do
    <<~OUTPUT
      Reading package lists... Done
      Building dependency tree... Done
      Reading state information... Done
      Calculating upgrade... Done
      0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
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
      expect(executor.upgrade_all.upgraded_packages).to eq(%w[libssl3 openssl vim])
    end

    it 'includes raw stdout' do
      expect(executor.upgrade_all.stdout).to include('Setting up libssl3')
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
          .and_return(result(stdout: '', stderr: 'E: Unable to lock', exit_code: 100))
      end

      it 'reports failure' do
        upgrade_result = executor.upgrade_all
        expect(upgrade_result).not_to be_succeeded
        expect(upgrade_result.stderr).to include('Unable to lock')
      end
    end
  end

  describe '#upgrade_packages' do
    before do
      allow(connection).to receive(:execute)
        .with(a_string_including('--only-upgrade libssl3 openssl'))
        .and_return(result(stdout: sample_upgrade_output))
    end

    it 'returns an UpgradeResult' do
      upgrade_result = executor.upgrade_packages(packages: %w[libssl3 openssl])
      expect(upgrade_result).to be_a(PatchPilot::Linux::UpgradeResult)
    end

    it 'constructs command with package names' do
      executor.upgrade_packages(packages: %w[libssl3 openssl])
      expect(connection).to have_received(:execute)
        .with(a_string_including('--only-upgrade libssl3 openssl'))
    end

    it 'uses DEBIAN_FRONTEND=noninteractive' do
      executor.upgrade_packages(packages: %w[libssl3 openssl])
      expect(connection).to have_received(:execute)
        .with(a_string_starting_with('DEBIAN_FRONTEND=noninteractive'))
    end
  end

  describe '#reboot_required?' do
    it 'returns true when reboot file exists' do
      allow(connection).to receive(:execute)
        .with(described_class::REBOOT_CHECK_COMMAND)
        .and_return(result(stdout: "true\n"))
      expect(executor.reboot_required?).to be true
    end

    it 'returns false when reboot file does not exist' do
      allow(connection).to receive(:execute)
        .with(described_class::REBOOT_CHECK_COMMAND)
        .and_return(result(stdout: "false\n"))
      expect(executor.reboot_required?).to be false
    end

    context 'when command fails' do
      before do
        allow(connection).to receive(:execute)
          .with(described_class::REBOOT_CHECK_COMMAND)
          .and_return(result(stdout: '', stderr: 'error', exit_code: 1))
      end

      it 'raises Connection::CommandError' do
        expect { executor.reboot_required? }
          .to raise_error(PatchPilot::Connection::CommandError, /APT reboot check failed/)
      end
    end
  end
end
