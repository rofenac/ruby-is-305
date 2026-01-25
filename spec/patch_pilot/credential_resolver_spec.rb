# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/patch_pilot'

RSpec.describe PatchPilot::CredentialResolver do
  describe '.resolve' do
    context 'with no environment variables' do
      let(:credentials) do
        {
          'type' => 'ssh',
          'username' => 'admin',
          'port' => 22
        }
      end

      it 'returns credentials unchanged' do
        result = described_class.resolve(credentials)
        expect(result).to eq(credentials)
      end
    end

    context 'with environment variables' do
      before do
        allow(ENV).to receive(:fetch).with('TEST_USER', nil).and_return('testuser')
        allow(ENV).to receive(:fetch).with('TEST_DOMAIN', nil).and_return('TESTDOMAIN')
      end

      let(:credentials) do
        {
          'type' => 'winrm',
          'username' => '${TEST_USER}',
          'domain' => '${TEST_DOMAIN}'
        }
      end

      it 'expands environment variables' do
        result = described_class.resolve(credentials)
        expect(result['username']).to eq('testuser')
        expect(result['domain']).to eq('TESTDOMAIN')
      end

      it 'preserves non-variable values' do
        result = described_class.resolve(credentials)
        expect(result['type']).to eq('winrm')
      end
    end

    context 'with nested structures' do
      before do
        allow(ENV).to receive(:fetch).with('NESTED_VAR', nil).and_return('nested_value')
      end

      let(:credentials) do
        {
          'outer' => {
            'inner' => '${NESTED_VAR}'
          },
          'array' => ['${NESTED_VAR}', 'literal']
        }
      end

      it 'resolves variables in nested hashes' do
        result = described_class.resolve(credentials)
        expect(result['outer']['inner']).to eq('nested_value')
      end

      it 'resolves variables in arrays' do
        result = described_class.resolve(credentials)
        expect(result['array']).to eq(%w[nested_value literal])
      end
    end

    context 'with missing environment variable' do
      let(:credentials) do
        {
          'username' => '${UNDEFINED_VAR}'
        }
      end

      before do
        allow(ENV).to receive(:fetch).with('UNDEFINED_VAR', nil).and_return(nil)
      end

      it 'raises an error' do
        expect do
          described_class.resolve(credentials)
        end.to raise_error(PatchPilot::Error, /Environment variable not set: UNDEFINED_VAR/)
      end
    end

    context 'with mixed content in string' do
      before do
        allow(ENV).to receive(:fetch).with('USER', nil).and_return('admin')
        allow(ENV).to receive(:fetch).with('DOMAIN', nil).and_return('CORP')
      end

      let(:credentials) do
        {
          'username' => '${DOMAIN}\\${USER}'
        }
      end

      it 'expands multiple variables in one string' do
        result = described_class.resolve(credentials)
        expect(result['username']).to eq('CORP\\admin')
      end
    end
  end
end
