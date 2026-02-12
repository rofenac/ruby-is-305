# frozen_string_literal: true

require 'dotenv/load'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/cross_origin'
require_relative '../lib/patch_pilot'

# Enable CORS for development
configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  content_type :json
end

options '*' do
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
  200
end

# rubocop:disable Metrics/BlockLength
helpers do
  def inventory
    @inventory ||= PatchPilot.load_inventory
  end

  def find_asset(name)
    asset = inventory.find(name)
    halt 404, { error: "Asset not found: #{name}" }.to_json unless asset
    asset
  end

  def get_connection(asset)
    conn = asset.connect(inventory)
    conn.connect
    conn
  rescue PatchPilot::Connection::ConnectionError => e
    halt 503, { error: "Connection failed: #{e.message}" }.to_json
  rescue PatchPilot::Connection::AuthenticationError => e
    halt 401, { error: "Authentication failed: #{e.message}" }.to_json
  end

  def asset_to_hash(asset)
    { name: asset.hostname, ip: asset.ip, os: asset.os, credential_id: asset.credential_ref,
      deep_freeze: asset.deep_freeze?, package_manager: asset.package_manager }
  end

  def update_to_hash(update)
    { kb_number: update.kb_number, description: update.description,
      installed_on: update.installed_on&.to_s, installed_by: update.installed_by,
      security_update: update.security_update? }
  end

  def package_to_hash(package)
    { name: package.name, version: package.version, architecture: package.architecture }
  end

  def windows_updates_response(asset, conn)
    query = PatchPilot::Windows::UpdateQuery.new(conn)
    updates = query.installed_updates.map { |u| update_to_hash(u) }
    { asset: asset.hostname, os: asset.os, updates: updates,
      summary: { total: updates.size, security: updates.count { |u| u[:security_update] } } }
  end

  def linux_packages_response(asset, conn)
    pm = asset.package_manager || 'apt'
    query = PatchPilot::Linux::PackageQuery.for(conn, package_manager: pm)
    { asset: asset.hostname, os: asset.os, package_manager: pm,
      packages: { installed_count: query.installed_packages.size,
                  upgradable_count: query.upgradable_packages.size,
                  upgradable: query.upgradable_packages.map { |p| package_to_hash(p) } } }
  end

  def comparison_response(asset1, asset2, comparison, type)
    { asset1: asset1.hostname, asset2: asset2.hostname, type: type,
      comparison: { common: comparison[:common].first(100),
                    only_in_first: comparison[:only_self].first(100),
                    only_in_second: comparison[:only_other].first(100) },
      summary: { common_count: comparison[:common].size,
                 only_first_count: comparison[:only_self].size,
                 only_second_count: comparison[:only_other].size } }
  end

  def windows_comparison(asset1, asset2, conn1, conn2)
    query1 = PatchPilot::Windows::UpdateQuery.new(conn1)
    query2 = PatchPilot::Windows::UpdateQuery.new(conn2)
    comparison_response(asset1, asset2, query1.compare_with(query2), 'windows_updates')
  end

  def linux_comparison(asset1, asset2, conn1, conn2)
    query1 = PatchPilot::Linux::PackageQuery.for(conn1, package_manager: asset1.package_manager || 'apt')
    query2 = PatchPilot::Linux::PackageQuery.for(conn2, package_manager: asset2.package_manager || 'apt')
    comparison_response(asset1, asset2, query1.compare_with(query2), 'linux_packages')
  end

  def parse_json_body
    body = request.body.read
    return {} if body.empty?

    JSON.parse(body)
  rescue JSON::ParserError
    halt 400, { error: 'Invalid JSON in request body' }.to_json
  end

  def require_windows!(asset)
    halt 400, { error: "Endpoint requires Windows asset, got: #{asset.os}" }.to_json unless asset.windows?
  end

  def require_linux!(asset)
    halt 400, { error: "Endpoint requires Linux asset, got: #{asset.os}" }.to_json unless asset.linux?
  end

  def reject_deep_freeze!(asset)
    return unless asset.deep_freeze?

    halt 409, { error: "#{asset.hostname} is managed by Deep Freeze Enterprise — " \
                       'manual updates are disabled' }.to_json
  end

  def available_update_to_hash(update)
    { kb_number: update.kb_number, title: update.title,
      size_bytes: update.size_bytes, size_mb: update.size_mb,
      severity: update.severity, is_downloaded: update.downloaded?,
      categories: update.categories }
  end

  def installation_result_to_hash(asset, result)
    { asset: asset.hostname, result: result.result_text,
      succeeded: result.succeeded?, reboot_required: result.reboot_required?,
      update_count: result.update_count,
      updates: result.updates.map { |u| update_action_to_hash(u) } }
  end

  def update_action_to_hash(action)
    { kb_number: action.kb_number, title: action.title,
      result: action.result_text, succeeded: action.succeeded? }
  end

  def upgrade_result_to_hash(asset, result)
    hash = { asset: asset.hostname, succeeded: result.succeeded?,
             upgraded_count: result.upgraded_count,
             upgraded_packages: result.upgraded_packages }
    hash[:error] = result.stderr unless result.succeeded? || result.stderr.to_s.empty?
    hash
  end
end
# rubocop:enable Metrics/BlockLength

# Health check
get '/api/health' do
  json status: 'ok', timestamp: Time.now.iso8601
end

# List all assets
get '/api/inventory' do
  assets = inventory.assets.map { |a| asset_to_hash(a) }
  json assets: assets, count: assets.size
end

# Get single asset details
get '/api/assets/:name' do
  json asset_to_hash(find_asset(params[:name]))
end

# Check if asset is reachable
get '/api/assets/:name/status' do
  asset = find_asset(params[:name])
  conn = get_connection(asset)

  begin
    # Actually test the connection by executing a simple command
    result = conn.execute('echo test')
    status = result.success? ? 'online' : 'offline'
    json name: asset.hostname, status: status
  ensure
    conn.close
  end
rescue StandardError => e
  json name: asset.hostname, status: 'offline', error: e.message
end

# Get updates/packages for an asset
get '/api/assets/:name/updates' do
  asset = find_asset(params[:name])
  conn = get_connection(asset)

  begin
    halt 400, { error: "Unsupported OS: #{asset.os}" }.to_json unless asset.windows? || asset.linux?
    json(asset.windows? ? windows_updates_response(asset, conn) : linux_packages_response(asset, conn))
  ensure
    conn.close
  end
end

# Compare two assets
get '/api/compare' do
  halt 400, { error: 'Must specify asset1 and asset2' }.to_json unless params[:asset1] && params[:asset2]

  asset1 = find_asset(params[:asset1])
  asset2 = find_asset(params[:asset2])
  halt 400, { error: 'Cannot compare Windows and Linux assets' }.to_json if asset1.windows? != asset2.windows?

  conn1 = get_connection(asset1)
  conn2 = get_connection(asset2)

  begin
    result = if asset1.windows?
               windows_comparison(asset1, asset2, conn1, conn2)
             else
               linux_comparison(asset1, asset2, conn1, conn2)
             end
    json(result)
  ensure
    conn1.close
    conn2.close
  end
end

# Get available (not yet installed) updates for a Windows asset
get '/api/assets/:name/updates/available' do
  asset = find_asset(params[:name])
  require_windows!(asset)
  conn = get_connection(asset)

  begin
    executor = PatchPilot::Windows::UpdateExecutor.new(conn)
    updates = executor.available_updates
    reboot = executor.reboot_required?
    json asset: asset.hostname, available_updates: updates.map { |u| available_update_to_hash(u) },
         summary: { total: updates.size, security: updates.count(&:security?),
                    downloaded: updates.count(&:downloaded?) },
         reboot_pending: reboot
  ensure
    conn.close
  end
end

# Install Windows updates
post '/api/assets/:name/updates/install' do
  asset = find_asset(params[:name])
  require_windows!(asset)
  reject_deep_freeze!(asset)
  conn = get_connection(asset)

  begin
    body = parse_json_body
    kb_numbers = body['kb_numbers']
    kb_numbers = nil if kb_numbers.is_a?(Array) && kb_numbers.empty?

    executor = PatchPilot::Windows::UpdateExecutor.new(conn)
    if executor.reboot_required?
      halt 409, { error: "#{asset.hostname} has a pending reboot — " \
                         'reboot before installing updates' }.to_json
    end
    result = executor.install_updates(kb_numbers: kb_numbers)
    json installation_result_to_hash(asset, result)
  rescue PatchPilot::Connection::CommandError => e
    halt 500, { error: "Installation failed: #{e.message}" }.to_json
  ensure
    conn.close
  end
end

# Upgrade Linux packages
post '/api/assets/:name/packages/upgrade' do
  asset = find_asset(params[:name])
  require_linux!(asset)
  conn = get_connection(asset)

  begin
    body = parse_json_body
    packages = body['packages']
    pm = asset.package_manager || 'apt'
    executor = PatchPilot::Linux::PackageExecutor.for(conn, package_manager: pm)
    if executor.reboot_required?
      halt 409, { error: "#{asset.hostname} has a pending reboot — " \
                         'reboot before upgrading packages' }.to_json
    end

    result = if packages.is_a?(Array) && !packages.empty?
               executor.upgrade_packages(packages: packages)
             else
               executor.upgrade_all
             end
    json upgrade_result_to_hash(asset, result)
  rescue PatchPilot::Connection::CommandError => e
    halt 500, { error: "Upgrade failed: #{e.message}" }.to_json
  ensure
    conn.close
  end
end

# Check if an asset needs a reboot
get '/api/assets/:name/reboot-status' do
  asset = find_asset(params[:name])
  halt 400, { error: "Unsupported OS: #{asset.os}" }.to_json unless asset.windows? || asset.linux?
  conn = get_connection(asset)

  begin
    reboot = if asset.windows?
               PatchPilot::Windows::UpdateExecutor.new(conn).reboot_required?
             else
               pm = asset.package_manager || 'apt'
               PatchPilot::Linux::PackageExecutor.for(conn, package_manager: pm).reboot_required?
             end
    response_hash = { asset: asset.hostname, reboot_required: reboot }
    response_hash[:deep_freeze] = true if asset.deep_freeze?
    json response_hash
  ensure
    conn.close
  end
end

# Reboot an asset
post '/api/assets/:name/reboot' do
  asset = find_asset(params[:name])
  halt 400, { error: "Unsupported OS: #{asset.os}" }.to_json unless asset.windows? || asset.linux?
  reject_deep_freeze!(asset)
  conn = get_connection(asset)

  begin
    if asset.windows?
      PatchPilot::Windows::UpdateExecutor.new(conn).reboot
    else
      conn.execute('sudo reboot')
    end
    json asset: asset.hostname, rebooting: true, deep_freeze: asset.deep_freeze?
  rescue PatchPilot::Connection::CommandError
    # Connection may drop during reboot — treat as success
    json asset: asset.hostname, rebooting: true, deep_freeze: asset.deep_freeze?
  ensure
    begin
      conn.close
    rescue StandardError # rubocop:disable Lint/SuppressedException
    end
  end
end
