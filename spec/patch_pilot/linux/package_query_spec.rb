# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'

RSpec.describe PatchPilot::Linux::Package do
  let(:installed_package) do
    described_class.new(
      name: 'vim',
      version: '2:9.0.1378-2',
      architecture: 'amd64',
      status: 'installed'
    )
  end

  let(:upgradable_package) do
    described_class.new(
      name: 'openssh-server',
      version: '1:9.6p1-4',
      architecture: 'amd64',
      status: 'upgradable'
    )
  end

  describe '#upgradable?' do
    it 'returns true for upgradable packages' do
      expect(upgradable_package.upgradable?).to be true
    end

    it 'returns false for installed packages' do
      expect(installed_package.upgradable?).to be false
    end
  end

  describe '#matches_name?' do
    it 'matches string pattern' do
      expect(installed_package.matches_name?('vim')).to be true
      expect(installed_package.matches_name?('emacs')).to be false
    end

    it 'matches partial string' do
      expect(installed_package.matches_name?('vi')).to be true
    end

    it 'matches regex pattern' do
      expect(installed_package.matches_name?(/^vim$/)).to be true
      expect(installed_package.matches_name?(/^vi$/)).to be false
    end

    it 'handles nil name gracefully' do
      package = described_class.new(name: nil)
      expect(package.matches_name?('test')).to be false
    end
  end
end

RSpec.describe PatchPilot::Linux::PackageQuery do
  let(:connection) { instance_double(PatchPilot::Connections::SSH) }

  describe '.for' do
    it 'returns AptQuery for apt package manager' do
      query = described_class.for(connection, package_manager: 'apt')
      expect(query).to be_a(PatchPilot::Linux::AptQuery)
    end

    it 'returns DnfQuery for dnf package manager' do
      query = described_class.for(connection, package_manager: 'dnf')
      expect(query).to be_a(PatchPilot::Linux::DnfQuery)
    end

    it 'accepts symbol package manager' do
      query = described_class.for(connection, package_manager: :apt)
      expect(query).to be_a(PatchPilot::Linux::AptQuery)
    end

    it 'raises error for unknown package manager' do
      expect do
        described_class.for(connection, package_manager: 'unknown')
      end.to raise_error(PatchPilot::Error, 'Unknown package manager: unknown')
    end
  end
end
