#!/usr/bin/env ruby
# SPDX-License-Identifier: EUPL-1.2
require 'json'
require 'net/http'
require 'uri'
require 'digest'
require 'fileutils'
require 'optparse'
require 'cgi'

module Releases
  class MissingAsset < StandardError; end

  ROOT = File.expand_path('..', __dir__)
  API = 'https://api.github.com/repos/doublecmd/doublecmd/releases'.freeze
  ARCHES = { 'arm' => /(?:^|[._-])(?:aarch64|arm64)(?:[._-]|$)/i,
             'intel' => /(?:^|[._-])(?:x86_64|amd64|x64)(?:[._-]|$)/i }.freeze

  def self.get(url, redirects = 5)
    raise 'Too many redirects' if redirects.negative?

    uri = URI(url)
    raise 'HTTPS required' unless uri.scheme == 'https'

    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'homebrew-doublecmd'
    if uri.host == 'api.github.com'
      request['Accept'] = 'application/vnd.github+json'
      request['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}" if ENV['GITHUB_TOKEN']
    end
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 120) { |http| http.request(request) }
    return get(URI.join(url, response['location']).to_s, redirects - 1) if response.is_a?(Net::HTTPRedirection)
    raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  end

  def self.all
    result = []
    page = 1
    loop do
      batch = JSON.parse(get("#{API}?per_page=100&page=#{page}"))
      result.concat(batch)
      break if batch.length < 100

      page += 1
    end
    result.reject { |r| r['draft'] }
  end

  def self.version(release)
    match = /\Av?(\d+\.\d+\.\d+)\z/.match(release.fetch('tag_name'))
    match && match[1]
  end

  def self.latest(releases)
    releases.reject { |r| r['draft'] || r['prerelease'] || !version(r) }
            .max_by { |r| version(r).split('.').map(&:to_i) } || raise('No eligible release')
  end

  def self.assets(release)
    ARCHES.each_with_object({}) do |(arch, pattern), found|
      candidates = release.fetch('assets').select do |a|
        a['state'] == 'uploaded' && a['name'].downcase.end_with?('.dmg') && a['name'].match?(pattern)
      end
      raise MissingAsset, "#{release['tag_name']}: no #{arch} DMG yet" if candidates.empty?
      raise "#{release['tag_name']}: ambiguous #{arch} DMGs" if candidates.length > 1

      found[arch] = candidates.first
    end
  end

  def self.manifest(release)
    raise 'Unsupported version tag' unless version(release)

    selected = assets(release)
    data = { 'version' => version(release), 'tag' => release['tag_name'], 'release_url' => release['html_url'], 'assets' => {} }
    selected.each do |arch, asset|
      url = asset.fetch('browser_download_url')
      raise 'Unexpected asset origin' unless url.start_with?('https://github.com/doublecmd/doublecmd/releases/download/')

      cache = File.join(ROOT, '.cache',
                        "#{asset.fetch('id')}-#{Digest::SHA256.hexdigest(asset.values_at('updated_at', 'digest', 'size').to_json)}.dmg")
      FileUtils.mkdir_p(File.dirname(cache))
      unless File.exist?(cache)
        File.binwrite("#{cache}.partial", get(url))
        File.rename("#{cache}.partial", cache)
      end
      raise 'Asset size mismatch' unless File.size(cache) == asset.fetch('size')

      hash = Digest::SHA256.file(cache).hexdigest
      raise "Digest mismatch for #{asset['name']}" if asset['digest'] && asset['digest'] != "sha256:#{hash}"

      data['assets'][arch] =
        { 'id' => asset['id'], 'name' => asset['name'], 'url' => url, 'sha256' => hash, 'updated_at' => asset['updated_at'],
          'size' => asset['size'], 'digest' => asset['digest'] }
    end
    data
  end

  def self.cask(data)
    arm, intel = data.fetch('assets').values_at('arm', 'intel')
    <<~RUBY
      # SPDX-License-Identifier: EUPL-1.2
      # Derived from Homebrew/homebrew-cask; see NOTICE and test/fixtures/HOMEBREW-LICENSE.
      cask "double-commander" do
        version #{data.fetch('version').inspect}
        sha256 arm:   #{arm.fetch('sha256').inspect},
               intel: #{intel.fetch('sha256').inspect}

        on_arm do
          url #{arm.fetch('url').inspect}
        end
        on_intel do
          url #{intel.fetch('url').inspect}
        end

        name "Double Commander"
        desc "File manager with two panels"
        homepage "https://doublecmd.sourceforge.io/"

        livecheck do
          url "https://github.com/doublecmd/doublecmd/releases/latest"
          strategy :github_latest
        end

        depends_on :macos
        app "Double Commander.app"

        postflight_steps do
          run "/usr/bin/xattr",
              args: ["-cr", "{{appdir}}/Double Commander.app"],
              must_succeed: true
        end

        zap trash: "~/Library/Caches/doublecmd"
      end
    RUBY
  end

  def self.html(data)
    escape = ->(value) { CGI.escapeHTML(value.to_s) }
    links = data.fetch('assets').map do |arch, asset|
      "<li><a href=\"#{escape.call(asset['url'])}\">#{arch == 'arm' ? 'Apple Silicon' : 'Intel x86_64'}</a>" \
        "<br>SHA-256: <code>#{asset['sha256']}</code></li>"
    end.join("\n")
    <<~HTML
      <!doctype html>
      <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Double Commander for macOS</title><style>body{font:18px system-ui;max-width:850px;margin:3rem auto;padding:0 1rem;line-height:1.6}pre{overflow:auto;background:#eee;padding:1rem}code{overflow-wrap:anywhere}li{margin-bottom:1rem}</style></head><body>
      <h1>Double Commander for macOS</h1><p>Unofficial Homebrew tap. Tracked release: <a href="#{escape.call(data['release_url'])}">#{escape.call(data['version'])}</a>. macOS 11 or newer.</p>
      <pre>brew tap brozkeff/doublecmd
      brew trust --cask brozkeff/doublecmd/double-commander
      brew install --cask brozkeff/doublecmd/double-commander
      # Later:
      brew update
      brew upgrade --cask brozkeff/doublecmd/double-commander</pre>
      <h2>Direct upstream downloads</h2><ul>#{links}</ul>
      <p>The tap clears all extended attributes after each installation or upgrade. For manual installations, before first launch run:</p><pre>xattr -cr "/Applications/Double Commander.app/"</pre>
      <h2>Why this tap exists</h2><p>The official cask was disabled for failing Gatekeeper checks. This tap offers an explicit sideloading path and checks SHA-256 hashes, without notarization or PGP signature verification.</p>
      <p>Hashes verify downloaded bytes, not publisher identity. A compromised upstream account or build can publish malicious software with valid hashes. Clearing quarantine reduces macOS download protection. Weekly checks publish tap updates; they do not automatically upgrade your installed app.</p>
      <p><a href="https://doublecmd.sourceforge.io/">Upstream website</a> · <a href="https://github.com/doublecmd/doublecmd">Upstream GitHub</a> · <a href="https://github.com/Homebrew/homebrew-cask/blob/ef0757f8d941d65fca367e6f135c56bad820b1ae/Casks/d/double-commander.rb">Legacy official cask</a> · <a href="https://github.com/brozkeff/homebrew-doublecmd">Documentation and source</a></p>
      <p>Original tooling: EUPL-1.2. Double Commander: upstream GPLv2. Inherited Homebrew material retains BSD-2-Clause notices.</p>
      </body></html>
    HTML
  end

  def self.write(data, output)
    # Render everything before writing so discovery/hash failures cannot change published files.
    files = { 'release.json' => "#{JSON.pretty_generate(data)}\n", 'Casks/double-commander.rb' => cask(data),
              'docs/index.html' => html(data) }
    files.each do |path, content|
      target = File.join(output, path)
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, content)
    end
  end

  def self.run(argv)
    command = argv.shift
    options = { limit: 10, output: File.join(ROOT, 'tmp', 'preview') }
    OptionParser.new do |p|
      p.on('--limit N', Integer) { |v| options[:limit] = v }
      p.on('--last N', Integer) { |v| options[:last] = v }
      p.on('--tag TAG') { |v| options[:tag] = v }
      p.on('--output DIR') { |v| options[:output] = v }
      p.on('--check') { options[:check] = true }
    end.parse!(argv)
    raise 'Unexpected arguments' unless argv.empty?
    raise 'Counts must be positive' if options.values_at(:limit, :last).compact.any? { |n| n <= 0 }

    case command
    when 'list', 'render'
      releases = all.sort_by { |r| r.fetch('published_at') }.reverse
      if command == 'list'
        releases.first(options[:limit]).each do |r|
          begin
            available = assets(r).keys.join(', ')
          rescue StandardError => e
            available = e.message
          end
          puts "#{r['tag_name']}\t#{r['published_at']}\tprerelease=#{r['prerelease']}\t#{available}"
        end
      elsif options[:tag]
        release = releases.find { |r| r['tag_name'] == options[:tag] } || raise('Tag not found')
        write(manifest(release), options[:output])
      elsif options[:last]
        rows = releases.first(options[:last]).each_with_index.map do |r, index|
          directory = "release-#{index + 1}"
          begin
            write(manifest(r), File.join(options[:output], directory))
            "<li><a href=\"#{directory}/docs/index.html\">#{CGI.escapeHTML(r['tag_name'])}</a> (prerelease=#{r['prerelease']})</li>"
          rescue StandardError => e
            "<li>#{CGI.escapeHTML(r['tag_name'])}: #{CGI.escapeHTML(e.message)}</li>"
          end
        end
        FileUtils.mkdir_p(options[:output])
        File.write(File.join(options[:output], 'index.html'),
                   '<!doctype html><html lang="en"><meta charset="utf-8"><title>Release previews</title>' \
                   "<h1>Release previews</h1><ul>#{rows.join}</ul></html>")
      else
        raise 'render requires --tag or --last'
      end
    when 'update'
      release = latest(all)
      old_path = File.join(ROOT, 'release.json')
      old = File.exist?(old_path) ? JSON.parse(File.read(old_path)) : nil
      selected = nil
      begin
        selected = assets(release)
      rescue MissingAsset => e
        puts "Waiting for complete release: #{e.message}"
      end
      return unless selected

      if old
        comparison = version(release).split('.').map(&:to_i) <=> old.fetch('version').split('.').map(&:to_i)
        raise 'Refusing downgrade' if comparison.negative?

        if comparison.zero?
          unchanged = old['tag'] == release['tag_name'] && selected.all? do |arch, asset|
            saved = old['assets'].fetch(arch)
            %w[id name updated_at size digest].all? { |key| saved[key] == asset[key] } && saved['url'] == asset['browser_download_url']
          end
          raise 'Published release assets changed; investigate manually' unless unchanged

          puts 'Already up to date'
          return
        end
      end
      data = manifest(release)
      if options[:check]
        puts "Would publish #{data['version']}"
      else
        write(data, ROOT)
        puts "Published #{data['version']} locally"
      end
    else
      raise 'Usage: releases.rb list|render|update [options]'
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    Releases.run(ARGV)
  rescue StandardError => e
    warn e.message
    exit 1
  end
end
