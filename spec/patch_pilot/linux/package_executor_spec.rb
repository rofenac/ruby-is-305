# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/patch_pilot'

RSpec.describe PatchPilot::Linux::UpgradeResult do
  describe '#succeeded?' do
    it 'returns true when success is true' do
      result = described_class.new(success: true)
      expect(result).to be_succeeded
    end

    it 'returns false when success is false' do
      result = described_class.new(success: false)
      expect(result).not_to be_succeeded
    end
  end
end

RSpec.describe PatchPilot::Linux::PackageExecutor do
  let(:connection) { instance_double(PatchPilot::Connections::SSH) }

  describe '.for' do
    it 'returns AptExecutor for apt package manager' do
      executor = described_class.for(connection, package_manager: 'apt')
      expect(executor).to be_a(PatchPilot::Linux::AptExecutor)
    end

    it 'returns DnfExecutor for dnf package manager' do
      executor = described_class.for(connection, package_manager: 'dnf')
      expect(executor).to be_a(PatchPilot::Linux::DnfExecutor)
    end

    it 'accepts symbol package manager' do
      executor = described_class.for(connection, package_manager: :apt)
      expect(executor).to be_a(PatchPilot::Linux::AptExecutor)
    end

    it 'raises error for unknown package manager' do
      expect do
        described_class.for(connection, package_manager: 'unknown')
      end.to raise_error(PatchPilot::Error, 'Unknown package manager: unknown')
    end
  end
end
