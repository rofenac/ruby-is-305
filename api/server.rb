# frozen_string_literal: true

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
  conn.close
  json name: asset.hostname, status: 'online'
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
