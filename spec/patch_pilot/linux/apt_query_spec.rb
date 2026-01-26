# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'

RSpec.describe PatchPilot::Linux::AptQuery do
  let(:connection) { instance_double(PatchPilot::Connections::SSH) }
  let(:query) { described_class.new(connection) }

  let(:sample_dpkg_output) do
    <<~OUTPUT
      vim	2:9.0.1378-2	amd64	install ok installed
      openssh-server	1:9.6p1-3	amd64	install ok installed
      curl	8.5.0-2	amd64	install ok installed
      python3	3.12.3-1	amd64	install ok installed
    OUTPUT
  end

  let(:sample_upgradable_output) do
    <<~OUTPUT
      curl/jammy-updates 8.5.0-3 amd64 [upgradable from: 8.5.0-2]
      python3/jammy-updates 3.12.3-2 amd64 [upgradable from: 3.12.3-1]
    OUTPUT
  end

  let(:installed_result) do
    PatchPilot::Connection::Result.new(stdout: sample_dpkg_output, stderr: '', exit_code: 0)
  end

  let(:upgradable_result) do
    PatchPilot::Connection::Result.new(stdout: sample_upgradable_output, stderr: '', exit_code: 0)
  end

  before do
    allow(connection).to receive(:execute)
      .with(described_class::INSTALLED_COMMAND)
      .and_return(installed_result)
    allow(connection).to receive(:execute)
      .with(described_class::UPGRADABLE_COMMAND)
      .and_return(upgradable_result)
  end

  describe '#installed_packages' do
    it 'returns array of Package objects' do
      packages = query.installed_packages
      expect(packages).to all(be_a(PatchPilot::Linux::Package))
    end

    it 'parses package names correctly' do
      packages = query.installed_packages
      expect(packages.map(&:name)).to eq(%w[vim openssh-server curl python3])
    end

    it 'parses versions correctly' do
      packages = query.installed_packages
      expect(packages[0].version).to eq('2:9.0.1378-2')
      expect(packages[1].version).to eq('1:9.6p1-3')
    end

    it 'parses architecture correctly' do
      packages = query.installed_packages
      expect(packages.map(&:architecture)).to all(eq('amd64'))
    end

    it 'sets status to installed' do
      packages = query.installed_packages
      expect(packages.map(&:status)).to all(eq('installed'))
    end

    it 'caches results' do
      query.installed_packages
      query.installed_packages
      expect(connection).to have_received(:execute)
        .with(described_class::INSTALLED_COMMAND).once
    end

    it 'refreshes when requested' do
      query.installed_packages
      query.installed_packages(refresh: true)
      expect(connection).to have_received(:execute)
        .with(described_class::INSTALLED_COMMAND).twice
    end

    context 'with empty output' do
      let(:installed_result) do
        PatchPilot::Connection::Result.new(stdout: '', stderr: '', exit_code: 0)
      end

      it 'returns empty array' do
        expect(query.installed_packages).to eq([])
      end
    end

    context 'with malformed lines' do
      let(:sample_dpkg_output) do
        <<~OUTPUT
          vim	2:9.0.1378-2	amd64	install ok installed
          incomplete-line
          curl	8.5.0-2	amd64	install ok installed
        OUTPUT
      end

      it 'skips malformed lines' do
        packages = query.installed_packages
        expect(packages.map(&:name)).to eq(%w[vim curl])
      end
    end

    context 'with non-installed packages' do
      let(:sample_dpkg_output) do
        <<~OUTPUT
          vim	2:9.0.1378-2	amd64	install ok installed
          removed-pkg	1.0.0	amd64	deinstall ok config-files
        OUTPUT
      end

      it 'excludes non-installed packages' do
        packages = query.installed_packages
        expect(packages.map(&:name)).to eq(%w[vim])
      end
    end
  end

  describe '#upgradable_packages' do
    it 'returns array of Package objects' do
      packages = query.upgradable_packages
      expect(packages).to all(be_a(PatchPilot::Linux::Package))
    end

    it 'parses package names correctly' do
      packages = query.upgradable_packages
      expect(packages.map(&:name)).to eq(%w[curl python3])
    end

    it 'parses new versions correctly' do
      packages = query.upgradable_packages
      expect(packages[0].version).to eq('8.5.0-3')
      expect(packages[1].version).to eq('3.12.3-2')
    end

    it 'sets status to upgradable' do
      packages = query.upgradable_packages
      expect(packages.map(&:status)).to all(eq('upgradable'))
    end

    it 'caches results' do
      query.upgradable_packages
      query.upgradable_packages
      expect(connection).to have_received(:execute)
        .with(described_class::UPGRADABLE_COMMAND).once
    end

    context 'with empty output' do
      let(:upgradable_result) do
        PatchPilot::Connection::Result.new(stdout: '', stderr: '', exit_code: 0)
      end

      it 'returns empty array' do
        expect(query.upgradable_packages).to eq([])
      end
    end
  end

  describe '#packages_matching' do
    it 'filters by string pattern' do
      packages = query.packages_matching('ssh')
      expect(packages.count).to eq(1)
      expect(packages.first.name).to eq('openssh-server')
    end

    it 'filters by regex pattern' do
      packages = query.packages_matching(/^(vim|curl)$/)
      expect(packages.count).to eq(2)
      expect(packages.map(&:name)).to contain_exactly('vim', 'curl')
    end
  end

  describe '#package_names' do
    it 'returns array of package names' do
      expect(query.package_names).to eq(%w[vim openssh-server curl python3])
    end
  end

  describe '#compare_with' do
    let(:other_connection) { instance_double(PatchPilot::Connections::SSH) }
    let(:other_query) { described_class.new(other_connection) }

    let(:other_dpkg_output) do
      <<~OUTPUT
        vim	2:9.0.1378-2	amd64	install ok installed
        curl	8.5.0-2	amd64	install ok installed
        nginx	1.24.0-1	amd64	install ok installed
      OUTPUT
    end

    before do
      other_result = PatchPilot::Connection::Result.new(
        stdout: other_dpkg_output, stderr: '', exit_code: 0
      )
      allow(other_connection).to receive(:execute)
        .with(described_class::INSTALLED_COMMAND)
        .and_return(other_result)
    end

    it 'identifies common packages' do
      comparison = query.compare_with(other_query)
      expect(comparison[:common]).to contain_exactly('vim', 'curl')
    end

    it 'identifies packages only in self' do
      comparison = query.compare_with(other_query)
      expect(comparison[:only_self]).to contain_exactly('openssh-server', 'python3')
    end

    it 'identifies packages only in other' do
      comparison = query.compare_with(other_query)
      expect(comparison[:only_other]).to contain_exactly('nginx')
    end
  end

  describe '#summary' do
    it 'returns formatted summary' do
      summary = query.summary
      expect(summary).to include('Installed packages: 4')
      expect(summary).to include('Upgradable packages: 2')
    end
  end
end
