# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'

RSpec.describe PatchPilot::Linux::DnfQuery do
  let(:connection) { instance_double(PatchPilot::Connections::SSH) }
  let(:query) { described_class.new(connection) }

  let(:sample_installed_output) do
    <<~OUTPUT
      vim-enhanced.x86_64                  2:9.0.2081-1.fc43              @updates
      openssh-server.x86_64                9.6p1-1.fc43                   @System
      curl.x86_64                          8.5.0-2.fc43                   @updates
      python3.x86_64                       3.12.3-1.fc43                  @System
      basesystem.noarch                    11-18.fc43                     @System
    OUTPUT
  end

  let(:sample_upgradable_output) do
    <<~OUTPUT
      curl.x86_64                          8.5.0-3.fc43                   updates
      python3.x86_64                       3.12.3-2.fc43                  updates
    OUTPUT
  end

  let(:installed_result) do
    PatchPilot::Connection::Result.new(stdout: sample_installed_output, stderr: '', exit_code: 0)
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
      expect(packages.map(&:name)).to eq(%w[vim-enhanced openssh-server curl python3 basesystem])
    end

    it 'parses versions correctly' do
      packages = query.installed_packages
      expect(packages[0].version).to eq('2:9.0.2081-1.fc43')
      expect(packages[1].version).to eq('9.6p1-1.fc43')
    end

    it 'parses architecture correctly' do
      packages = query.installed_packages
      expect(packages[0].architecture).to eq('x86_64')
      expect(packages[4].architecture).to eq('noarch')
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
      let(:sample_installed_output) do
        <<~OUTPUT
          vim-enhanced.x86_64                  2:9.0.2081-1.fc43              @updates
          incomplete
          curl.x86_64                          8.5.0-2.fc43                   @updates
        OUTPUT
      end

      it 'skips malformed lines' do
        packages = query.installed_packages
        expect(packages.map(&:name)).to eq(%w[vim-enhanced curl])
      end
    end

    context 'with packages without architecture' do
      let(:sample_installed_output) do
        <<~OUTPUT
          vim-enhanced.x86_64                  2:9.0.2081-1.fc43              @updates
          nodotpackage                         1.0.0                          @System
        OUTPUT
      end

      it 'skips packages without architecture separator' do
        packages = query.installed_packages
        expect(packages.map(&:name)).to eq(%w[vim-enhanced])
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
      expect(packages[0].version).to eq('8.5.0-3.fc43')
      expect(packages[1].version).to eq('3.12.3-2.fc43')
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
      packages = query.packages_matching(/^(vim-enhanced|curl)$/)
      expect(packages.count).to eq(2)
      expect(packages.map(&:name)).to contain_exactly('vim-enhanced', 'curl')
    end
  end

  describe '#package_names' do
    it 'returns array of package names' do
      expect(query.package_names).to eq(%w[vim-enhanced openssh-server curl python3 basesystem])
    end
  end

  describe '#compare_with' do
    let(:other_connection) { instance_double(PatchPilot::Connections::SSH) }
    let(:other_query) { described_class.new(other_connection) }

    let(:other_installed_output) do
      <<~OUTPUT
        vim-enhanced.x86_64                  2:9.0.2081-1.fc43              @updates
        curl.x86_64                          8.5.0-2.fc43                   @updates
        nginx.x86_64                         1.24.0-1.fc43                  @updates
      OUTPUT
    end

    before do
      other_result = PatchPilot::Connection::Result.new(
        stdout: other_installed_output, stderr: '', exit_code: 0
      )
      allow(other_connection).to receive(:execute)
        .with(described_class::INSTALLED_COMMAND)
        .and_return(other_result)
    end

    it 'identifies common packages' do
      comparison = query.compare_with(other_query)
      expect(comparison[:common]).to contain_exactly('vim-enhanced', 'curl')
    end

    it 'identifies packages only in self' do
      comparison = query.compare_with(other_query)
      expect(comparison[:only_self]).to contain_exactly('openssh-server', 'python3', 'basesystem')
    end

    it 'identifies packages only in other' do
      comparison = query.compare_with(other_query)
      expect(comparison[:only_other]).to contain_exactly('nginx')
    end
  end

  describe '#summary' do
    it 'returns formatted summary' do
      summary = query.summary
      expect(summary).to include('Installed packages: 5')
      expect(summary).to include('Upgradable packages: 2')
    end
  end
end
