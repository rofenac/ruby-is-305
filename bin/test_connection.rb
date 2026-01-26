#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick connectivity test script
# Usage: source .env && bundle exec ruby bin/test_connection.rb [hostname]

require_relative '../lib/patch_pilot'

hostname = ARGV[0] || 'dc01'

puts 'Loading inventory...'
inventory = PatchPilot.load_inventory

asset = inventory.find(hostname)
if asset.nil?
  puts "Asset '#{hostname}' not found in inventory"
  exit 1
end

puts "Connecting to #{asset.hostname} (#{asset.ip})..."
puts "  OS: #{asset.os}"
puts "  Credential: #{asset.credential_ref}"

begin
  conn = asset.connect(inventory)
  conn.connect

  puts "Connected! Running 'hostname' command..."
  result = conn.execute('hostname')

  puts "\nResult:"
  puts "  stdout: #{result.stdout.strip}"
  puts "  stderr: #{result.stderr.strip}" unless result.stderr.empty?
  puts "  exit_code: #{result.exit_code}"

  conn.close
  puts "\nConnection test successful!"
rescue PatchPilot::Connection::AuthenticationError => e
  puts "\nAuthentication failed: #{e.message}"
  exit 1
rescue PatchPilot::Connection::ConnectionError => e
  puts "\nConnection failed: #{e.message}"
  exit 1
rescue StandardError => e
  puts "\nError: #{e.class} - #{e.message}"
  exit 1
end
