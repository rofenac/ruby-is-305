# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'spec_helper'
require 'rack/test'
require 'json'
require_relative '../../lib/patch_pilot'
require_relative '../../lib/patch_pilot/connections/winrm'
require_relative '../../lib/patch_pilot/connections/ssh'
require_relative '../../api/server'

RSpec.describe 'PatchPilot API - Execution Endpoints' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  let(:windows_asset) do
    PatchPilot::Asset.new(
      'hostname' => 'PC1', 'ip' => '172.29.10.18', 'os' => 'windows_desktop',
      'credential_ref' => 'windows_domain', 'deep_freeze' => true, 'tags' => []
    )
  end

  let(:windows_asset_no_df) do
    PatchPilot::Asset.new(
      'hostname' => 'PC2', 'ip' => '172.29.10.19', 'os' => 'windows_desktop',
      'credential_ref' => 'windows_domain', 'deep_freeze' => false, 'tags' => []
    )
  end

  let(:linux_asset) do
    PatchPilot::Asset.new(
      'hostname' => 'kali', 'ip' => '172.29.70.14', 'os' => 'linux',
      'credential_ref' => 'linux_ssh', 'package_manager' => 'apt', 'tags' => []
    )
  end

  let(:winrm_conn) { instance_double(PatchPilot::Connections::WinRM) }
  let(:ssh_conn) { instance_double(PatchPilot::Connections::SSH) }

  let(:inventory) do
    instance_double(PatchPilot::Inventory, assets: [windows_asset, linux_asset],
                                           find: nil)
  end

  let(:update_executor) { instance_double(PatchPilot::Windows::UpdateExecutor) }
  let(:apt_executor) { instance_double(PatchPilot::Linux::AptExecutor) }

  before do
    allow(PatchPilot).to receive(:load_inventory).and_return(inventory)
    allow(inventory).to receive(:find).with('PC1').and_return(windows_asset)
    allow(inventory).to receive(:find).with('PC2').and_return(windows_asset_no_df)
    allow(inventory).to receive(:find).with('kali').and_return(linux_asset)
    allow(inventory).to receive(:find).with('unknown').and_return(nil)

    allow(windows_asset).to receive(:connect).and_return(winrm_conn)
    allow(windows_asset_no_df).to receive(:connect).and_return(winrm_conn)
    allow(winrm_conn).to receive(:connect).and_return(winrm_conn)
    allow(winrm_conn).to receive(:close)

    allow(linux_asset).to receive(:connect).and_return(ssh_conn)
    allow(ssh_conn).to receive(:connect).and_return(ssh_conn)
    allow(ssh_conn).to receive(:close)

    allow(PatchPilot::Windows::UpdateExecutor).to receive(:new).with(winrm_conn).and_return(update_executor)
    allow(PatchPilot::Linux::PackageExecutor).to receive(:for)
      .with(ssh_conn, package_manager: 'apt').and_return(apt_executor)
  end

  # --- GET /api/assets/:name/updates/available ---

  describe 'GET /api/assets/:name/updates/available' do
    let(:available_updates) do
      [
        PatchPilot::Windows::AvailableUpdate.new(
          kb_number: 'KB5073379', title: 'Cumulative Update', size_bytes: 524_288_000,
          severity: 'Critical', is_downloaded: false, categories: ['Security Updates']
        ),
        PatchPilot::Windows::AvailableUpdate.new(
          kb_number: 'KB890830', title: 'Malicious Software Removal Tool', size_bytes: 62_914_560,
          severity: 'Unspecified', is_downloaded: true, categories: ['Update Rollups']
        )
      ]
    end

    before do
      allow(update_executor).to receive(:available_updates).and_return(available_updates)
      allow(update_executor).to receive(:reboot_required?).and_return(false)
    end

    it 'returns available updates for a Windows asset' do
      get '/api/assets/PC1/updates/available'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['asset']).to eq('PC1')
      expect(body['available_updates'].size).to eq(2)
      expect(body['available_updates'].first['kb_number']).to eq('KB5073379')
    end

    it 'includes summary counts' do
      get '/api/assets/PC1/updates/available'
      body = JSON.parse(last_response.body)
      expect(body['summary']['total']).to eq(2)
      expect(body['summary']['security']).to eq(1)
      expect(body['summary']['downloaded']).to eq(1)
    end

    it 'serializes update fields correctly' do
      get '/api/assets/PC1/updates/available'
      update = JSON.parse(last_response.body)['available_updates'].first
      expect(update['title']).to eq('Cumulative Update')
      expect(update['size_bytes']).to eq(524_288_000)
      expect(update['size_mb']).to eq(500.0)
      expect(update['severity']).to eq('Critical')
      expect(update['is_downloaded']).to be false
      expect(update['categories']).to eq(['Security Updates'])
    end

    it 'includes reboot_pending false when no reboot needed' do
      get '/api/assets/PC1/updates/available'
      body = JSON.parse(last_response.body)
      expect(body['reboot_pending']).to be false
    end

    it 'includes reboot_pending true when reboot is needed' do
      allow(update_executor).to receive(:reboot_required?).and_return(true)
      get '/api/assets/PC1/updates/available'
      body = JSON.parse(last_response.body)
      expect(body['reboot_pending']).to be true
    end

    it 'returns empty array when no updates available' do
      allow(update_executor).to receive(:available_updates).and_return([])
      get '/api/assets/PC1/updates/available'
      body = JSON.parse(last_response.body)
      expect(body['available_updates']).to eq([])
      expect(body['summary']['total']).to eq(0)
    end

    it 'returns 400 for a Linux asset' do
      get '/api/assets/kali/updates/available'
      expect(last_response.status).to eq(400)
      body = JSON.parse(last_response.body)
      expect(body['error']).to include('Windows')
    end

    it 'returns 404 for an unknown asset' do
      get '/api/assets/unknown/updates/available'
      expect(last_response.status).to eq(404)
    end

    it 'returns 503 when connection fails' do
      allow(winrm_conn).to receive(:connect)
        .and_raise(PatchPilot::Connection::ConnectionError, 'Connection refused')
      get '/api/assets/PC1/updates/available'
      expect(last_response.status).to eq(503)
    end
  end

  # --- POST /api/assets/:name/updates/install ---

  describe 'POST /api/assets/:name/updates/install' do
    let(:install_result) do
      PatchPilot::Windows::InstallationResult.new(
        result_code: 2, result_text: 'Succeeded', reboot_required: true, update_count: 2,
        updates: [
          PatchPilot::Windows::UpdateActionResult.new(
            kb_number: 'KB5073379', title: 'Cumulative Update', result_code: 2, result_text: 'Succeeded'
          ),
          PatchPilot::Windows::UpdateActionResult.new(
            kb_number: 'KB890830', title: 'MSRT', result_code: 2, result_text: 'Succeeded'
          )
        ]
      )
    end

    before do
      allow(update_executor).to receive(:install_updates).and_return(install_result)
      allow(update_executor).to receive(:reboot_required?).and_return(false)
    end

    it 'installs all updates when no body is provided' do
      post '/api/assets/PC2/updates/install'
      expect(update_executor).to have_received(:install_updates).with(kb_numbers: nil)
      expect(last_response.status).to eq(200)
    end

    it 'returns installation result structure' do
      post '/api/assets/PC2/updates/install'
      body = JSON.parse(last_response.body)
      expect(body['asset']).to eq('PC2')
      expect(body['succeeded']).to be true
      expect(body['reboot_required']).to be true
      expect(body['update_count']).to eq(2)
      expect(body['updates'].size).to eq(2)
    end

    it 'passes specific KB numbers from request body' do
      post '/api/assets/PC2/updates/install',
           { kb_numbers: ['KB5073379'] }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }
      expect(update_executor).to have_received(:install_updates).with(kb_numbers: ['KB5073379'])
    end

    it 'treats empty kb_numbers array as install-all' do
      post '/api/assets/PC2/updates/install',
           { kb_numbers: [] }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }
      expect(update_executor).to have_received(:install_updates).with(kb_numbers: nil)
    end

    it 'returns per-update results' do
      post '/api/assets/PC2/updates/install'
      updates = JSON.parse(last_response.body)['updates']
      expect(updates.first['kb_number']).to eq('KB5073379')
      expect(updates.first['succeeded']).to be true
      expect(updates.first['result']).to eq('Succeeded')
    end

    it 'returns 409 for a Deep Freeze asset' do
      post '/api/assets/PC1/updates/install'
      expect(last_response.status).to eq(409)
      body = JSON.parse(last_response.body)
      expect(body['error']).to include('Deep Freeze')
    end

    it 'returns 409 when reboot is pending' do
      allow(update_executor).to receive(:reboot_required?).and_return(true)
      post '/api/assets/PC2/updates/install'
      expect(last_response.status).to eq(409)
      body = JSON.parse(last_response.body)
      expect(body['error']).to include('pending reboot')
    end

    it 'returns 400 for a Linux asset' do
      post '/api/assets/kali/updates/install'
      expect(last_response.status).to eq(400)
    end

    it 'returns 400 for invalid JSON body' do
      post '/api/assets/PC2/updates/install', 'not json', { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
      body = JSON.parse(last_response.body)
      expect(body['error']).to include('Invalid JSON')
    end

    it 'returns 500 when installation fails with CommandError' do
      allow(update_executor).to receive(:install_updates)
        .and_raise(PatchPilot::Connection::CommandError, 'PowerShell error')
      post '/api/assets/PC2/updates/install'
      expect(last_response.status).to eq(500)
      body = JSON.parse(last_response.body)
      expect(body['error']).to include('Installation failed')
    end

    it 'returns 404 for an unknown asset' do
      post '/api/assets/unknown/updates/install'
      expect(last_response.status).to eq(404)
    end
  end

  # --- POST /api/assets/:name/packages/upgrade ---

  describe 'POST /api/assets/:name/packages/upgrade' do
    let(:upgrade_result) do
      PatchPilot::Linux::UpgradeResult.new(
        success: true, upgraded_count: 3,
        upgraded_packages: %w[curl libcurl4 wget],
        stdout: '3 upgraded, 0 newly installed', stderr: ''
      )
    end

    before do
      allow(apt_executor).to receive(:upgrade_all).and_return(upgrade_result)
      allow(apt_executor).to receive(:upgrade_packages).and_return(upgrade_result)
      allow(apt_executor).to receive(:reboot_required?).and_return(false)
    end

    it 'upgrades all packages when no body is provided' do
      post '/api/assets/kali/packages/upgrade'
      expect(apt_executor).to have_received(:upgrade_all)
      expect(last_response.status).to eq(200)
    end

    it 'returns upgrade result structure' do
      post '/api/assets/kali/packages/upgrade'
      body = JSON.parse(last_response.body)
      expect(body['asset']).to eq('kali')
      expect(body['succeeded']).to be true
      expect(body['upgraded_count']).to eq(3)
      expect(body['upgraded_packages']).to eq(%w[curl libcurl4 wget])
    end

    it 'upgrades specific packages from request body' do
      post '/api/assets/kali/packages/upgrade',
           { packages: ['curl'] }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }
      expect(apt_executor).to have_received(:upgrade_packages).with(packages: ['curl'])
    end

    it 'treats empty packages array as upgrade-all' do
      post '/api/assets/kali/packages/upgrade',
           { packages: [] }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }
      expect(apt_executor).to have_received(:upgrade_all)
    end

    it 'does not include error field on success' do
      post '/api/assets/kali/packages/upgrade'
      body = JSON.parse(last_response.body)
      expect(body).not_to have_key('error')
    end

    it 'includes error field on failure' do
      failed = PatchPilot::Linux::UpgradeResult.new(
        success: false, upgraded_count: 0, upgraded_packages: [],
        stdout: '', stderr: 'E: Unable to lock'
      )
      allow(apt_executor).to receive(:upgrade_all).and_return(failed)
      post '/api/assets/kali/packages/upgrade'
      body = JSON.parse(last_response.body)
      expect(body['succeeded']).to be false
      expect(body['error']).to include('Unable to lock')
    end

    it 'returns 409 when reboot is pending' do
      allow(apt_executor).to receive(:reboot_required?).and_return(true)
      post '/api/assets/kali/packages/upgrade'
      expect(last_response.status).to eq(409)
      body = JSON.parse(last_response.body)
      expect(body['error']).to include('pending reboot')
    end

    it 'returns 400 for a Windows asset' do
      post '/api/assets/PC1/packages/upgrade'
      expect(last_response.status).to eq(400)
    end

    it 'returns 500 when CommandError is raised' do
      allow(apt_executor).to receive(:upgrade_all)
        .and_raise(PatchPilot::Connection::CommandError, 'SSH channel closed')
      post '/api/assets/kali/packages/upgrade'
      expect(last_response.status).to eq(500)
      body = JSON.parse(last_response.body)
      expect(body['error']).to include('Upgrade failed')
    end

    it 'returns 404 for an unknown asset' do
      post '/api/assets/unknown/packages/upgrade'
      expect(last_response.status).to eq(404)
    end
  end

  # --- GET /api/assets/:name/reboot-status ---

  describe 'GET /api/assets/:name/reboot-status' do
    it 'returns reboot_required true for Windows' do
      allow(update_executor).to receive(:reboot_required?).and_return(true)
      get '/api/assets/PC1/reboot-status'
      body = JSON.parse(last_response.body)
      expect(body['asset']).to eq('PC1')
      expect(body['reboot_required']).to be true
    end

    it 'returns reboot_required false for Windows' do
      allow(update_executor).to receive(:reboot_required?).and_return(false)
      get '/api/assets/PC1/reboot-status'
      body = JSON.parse(last_response.body)
      expect(body['reboot_required']).to be false
    end

    it 'includes deep_freeze flag for Deep Freeze assets' do
      allow(update_executor).to receive(:reboot_required?).and_return(true)
      get '/api/assets/PC1/reboot-status'
      body = JSON.parse(last_response.body)
      expect(body['deep_freeze']).to be true
    end

    it 'does not include deep_freeze for non-Deep Freeze assets' do
      allow(apt_executor).to receive(:reboot_required?).and_return(false)
      get '/api/assets/kali/reboot-status'
      body = JSON.parse(last_response.body)
      expect(body).not_to have_key('deep_freeze')
    end

    it 'returns reboot status for Linux' do
      allow(apt_executor).to receive(:reboot_required?).and_return(true)
      get '/api/assets/kali/reboot-status'
      body = JSON.parse(last_response.body)
      expect(body['asset']).to eq('kali')
      expect(body['reboot_required']).to be true
    end

    it 'returns 404 for an unknown asset' do
      get '/api/assets/unknown/reboot-status'
      expect(last_response.status).to eq(404)
    end

    it 'returns 503 when connection fails' do
      allow(winrm_conn).to receive(:connect)
        .and_raise(PatchPilot::Connection::ConnectionError, 'Timeout')
      get '/api/assets/PC1/reboot-status'
      expect(last_response.status).to eq(503)
    end
  end

  # --- POST /api/assets/:name/reboot ---

  describe 'POST /api/assets/:name/reboot' do
    it 'reboots a Windows asset' do
      allow(update_executor).to receive(:reboot)
        .and_return(PatchPilot::Connection::Result.new(stdout: '', stderr: '', exit_code: 0))
      post '/api/assets/PC2/reboot'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['asset']).to eq('PC2')
      expect(body['rebooting']).to be true
      expect(body['deep_freeze']).to be false
    end

    it 'reboots a Linux asset' do
      allow(ssh_conn).to receive(:execute)
        .and_return(PatchPilot::Connection::Result.new(stdout: '', stderr: '', exit_code: 0))
      post '/api/assets/kali/reboot'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['asset']).to eq('kali')
      expect(body['rebooting']).to be true
    end

    it 'returns 409 for a Deep Freeze asset' do
      post '/api/assets/PC1/reboot'
      expect(last_response.status).to eq(409)
      body = JSON.parse(last_response.body)
      expect(body['error']).to include('Deep Freeze')
    end

    it 'handles connection drop during Windows reboot' do
      allow(update_executor).to receive(:reboot)
        .and_raise(PatchPilot::Connection::CommandError, 'Connection reset')
      post '/api/assets/PC2/reboot'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['rebooting']).to be true
    end

    it 'handles connection drop during Linux reboot' do
      allow(ssh_conn).to receive(:execute)
        .and_raise(PatchPilot::Connection::CommandError, 'Connection reset')
      post '/api/assets/kali/reboot'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['rebooting']).to be true
    end

    it 'handles conn.close failure gracefully' do
      allow(update_executor).to receive(:reboot)
        .and_return(PatchPilot::Connection::Result.new(stdout: '', stderr: '', exit_code: 0))
      allow(winrm_conn).to receive(:close).and_raise(StandardError, 'already closed')
      post '/api/assets/PC2/reboot'
      expect(last_response.status).to eq(200)
    end

    it 'returns 404 for an unknown asset' do
      post '/api/assets/unknown/reboot'
      expect(last_response.status).to eq(404)
    end
  end
end
