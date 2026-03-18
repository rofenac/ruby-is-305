# frozen_string_literal: true

module PatchPilot
  # Pure data-transformation helpers for building API response hashes.
  # Included into Sinatra helpers — no framework dependencies.
  module Serializers
    def asset_to_hash(asset)
      { name: asset.hostname, ip: asset.ip, os: asset.os, os_version: asset.os_version,
        credential_id: asset.credential_ref, deep_freeze: asset.deep_freeze?,
        package_manager: asset.package_manager, role: asset.role, tags: asset.tags }
    end

    def update_to_hash(update)
      { kb_number: update.kb_number, description: update.description,
        installed_on: update.installed_on&.to_s, installed_by: update.installed_by,
        security_update: update.security_update? }
    end

    def package_to_hash(package)
      { name: package.name, version: package.version, architecture: package.architecture }
    end

    def available_update_to_hash(update)
      { kb_number: update.kb_number, title: update.title,
        size_bytes: update.size_bytes, size_mb: update.size_mb,
        severity: update.severity, is_downloaded: update.downloaded?,
        categories: update.categories }
    end

    def update_action_to_hash(action)
      { kb_number: action.kb_number, title: action.title,
        result: action.result_text, succeeded: action.succeeded? }
    end

    def installation_result_to_hash(asset, result)
      { asset: asset.hostname, result: result.result_text,
        succeeded: result.succeeded?, reboot_required: result.reboot_required?,
        update_count: result.update_count,
        updates: result.updates.map { |u| update_action_to_hash(u) } }
    end

    def upgrade_result_to_hash(asset, result)
      hash = { asset: asset.hostname, succeeded: result.succeeded?,
               upgraded_count: result.upgraded_count,
               upgraded_packages: result.upgraded_packages }
      hash[:error] = result.stderr unless result.succeeded? || result.stderr.to_s.empty?
      hash
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

    def windows_comparison(asset1, asset2, conn1, conn2)
      query1 = PatchPilot::Windows::UpdateQuery.new(conn1)
      query2 = PatchPilot::Windows::UpdateQuery.new(conn2)
      comparison_response(asset1, asset2, query1.compare_with(query2), 'windows_updates')
    end

    def linux_comparison(asset1, asset2, conn1, conn2)
      pm1 = asset1.package_manager || 'apt'
      pm2 = asset2.package_manager || 'apt'
      query1 = PatchPilot::Linux::PackageQuery.for(conn1, package_manager: pm1)
      query2 = PatchPilot::Linux::PackageQuery.for(conn2, package_manager: pm2)
      comparison_response(asset1, asset2, query1.compare_with(query2), 'linux_packages')
    end
  end
end
