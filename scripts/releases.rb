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
  CHANNELS = {
    'stable' => { api: 'https://api.github.com/repos/doublecmd/doublecmd/releases', file: 'release.json',
                  origin: 'https://github.com/doublecmd/doublecmd/releases/download/' },
    'snapshot' => { api: 'https://api.github.com/repos/doublecmd/snapshots/releases', file: 'snapshot.json',
                    origin: 'https://github.com/doublecmd/snapshots/releases/download/' }
  }.freeze
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

  def self.all(channel = 'stable')
    result = []
    page = 1
    loop do
      batch = JSON.parse(get("#{CHANNELS.fetch(channel).fetch(:api)}?per_page=100&page=#{page}"))
      result.concat(batch)
      break if batch.length < 100

      page += 1
    end
    result.reject { |r| r['draft'] }
  end

  def self.version(release, channel = 'stable')
    pattern = channel == 'snapshot' ? /\A(\d+)\z/ : /\Av?(\d+\.\d+\.\d+)\z/
    match = pattern.match(release.fetch('tag_name'))
    match && match[1]
  end

  def self.latest(releases, channel = 'stable')
    releases.reject { |r| r['draft'] || (channel == 'stable' && r['prerelease']) || !version(r, channel) }
            .max_by { |r| version(r, channel).split('.').map(&:to_i) } || raise('No eligible release')
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

  def self.manifest(release, channel = 'stable')
    raise 'Unsupported version tag' unless version(release, channel)

    selected = assets(release)
    data = { 'version' => version(release, channel), 'tag' => release['tag_name'], 'release_url' => release['html_url'], 'assets' => {} }
    selected.each do |arch, asset|
      url = asset.fetch('browser_download_url')
      raise 'Unexpected asset origin' unless url.start_with?(CHANNELS.fetch(channel).fetch(:origin))

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

  def self.channel_stanzas(data, channel)
    arm, intel = data.fetch('assets').values_at('arm', 'intel')
    livecheck_url = if channel == 'snapshot'
                      'https://github.com/doublecmd/snapshots/releases'
                    else
                      'https://github.com/doublecmd/doublecmd/releases/latest'
                    end
    livecheck_strategy = channel == 'snapshot' ? :github_releases : :github_latest
    livecheck_regex = channel == 'snapshot' ? '  regex(/^(\d+)$/)' : nil
    <<~RUBY
      version #{data.fetch('version').inspect}
      sha256 arm:   #{arm.fetch('sha256').inspect},
             intel: #{intel.fetch('sha256').inspect}

      on_arm do
        url #{arm.fetch('url').inspect}
      end
      on_intel do
        url #{intel.fetch('url').inspect}
      end

      livecheck do
        url #{livecheck_url.inspect}
        strategy #{livecheck_strategy.inspect}
      #{livecheck_regex}
      end
    RUBY
  end

  def self.cask(stable, snapshot = nil, channel: 'stable')
    stanzas = if snapshot
                [
                  'case ENV.fetch("HOMEBREW_DOUBLE_COMMANDER_CHANNEL", "stable")',
                  'when "stable"',
                  indent(channel_stanzas(stable, 'stable'), 2).rstrip,
                  'when "snapshot"',
                  indent(channel_stanzas(snapshot, 'snapshot'), 2).rstrip,
                  'else',
                  '  raise "Set HOMEBREW_DOUBLE_COMMANDER_CHANNEL to stable or snapshot"',
                  'end'
                ].join("\n")
              else
                channel_stanzas(stable, channel)
              end
    <<~RUBY
      # SPDX-License-Identifier: EUPL-1.2
      # Derived from Homebrew/homebrew-cask; see NOTICE and test/fixtures/HOMEBREW-LICENSE.
      cask "double-commander" do
      #{indent(stanzas, 2).rstrip}

        name "Double Commander"
        desc "File manager with two panels"
        homepage "https://doublecmd.sourceforge.io/"

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

  def self.indent(value, spaces)
    value.lines.map { |line| line.strip.empty? ? line : "#{' ' * spaces}#{line}" }.join
  end

  def self.html(data, snapshot = nil, channel: 'stable')
    escape = ->(value) { CGI.escapeHTML(value.to_s) }
    links = lambda do |release|
      release.fetch('assets').map do |arch, asset|
        "<li><a href=\"#{escape.call(asset['url'])}\">#{arch == 'arm' ? 'Apple Silicon' : 'Intel x86_64'}</a>" \
          "<br>SHA-256: <code>#{escape.call(asset['sha256'])}</code></li>"
      end.join("\n")
    end
    snapshot_info = if snapshot
                      release_url = escape.call(snapshot['release_url'])
                      revision = escape.call(snapshot['version'])
                      "<p>Snapshot channel: <a href=\"#{release_url}\">revision #{revision}</a>. " \
                        'Opt in by setting <code>HOMEBREW_DOUBLE_COMMANDER_CHANNEL=snapshot</code> in your shell environment. ' \
                        'Run <code>brew update</code> and <code>brew upgrade --cask brozkeff/doublecmd/double-commander</code>. ' \
                        'Remove the setting and upgrade again to return to the latest stable release, even when it is a downgrade.</p>' \
                        "<h2>Snapshot downloads</h2><ul>#{links.call(snapshot)}</ul>"
                    else
                      ''
                    end
    <<~HTML
      <!doctype html>
      <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Double Commander for macOS</title><style>body{font:18px system-ui;max-width:850px;margin:3rem auto;padding:0 1rem;line-height:1.6}pre{overflow:auto;background:#eee;padding:1rem}code{overflow-wrap:anywhere}li{margin-bottom:1rem}</style></head><body>
      <h1>Double Commander for macOS</h1><p>Unofficial Homebrew tap. Tracked #{channel} release: <a href="#{escape.call(data['release_url'])}">#{escape.call(data['version'])}</a>. macOS 11 or newer.</p>
      #{snapshot_info}
      <pre>brew tap brozkeff/doublecmd
      brew trust --cask brozkeff/doublecmd/double-commander
      brew install --cask brozkeff/doublecmd/double-commander
      # Later:
      brew update
      brew upgrade --cask brozkeff/doublecmd/double-commander</pre>
      <h2>#{channel.capitalize} downloads</h2><ul>#{links.call(data)}</ul>
      <p>The tap clears all extended attributes after each installation or upgrade. For manual installations, before first launch run:</p><pre>xattr -cr "/Applications/Double Commander.app/"</pre>
      <h2>Why this tap exists</h2><p>The official cask was disabled for failing Gatekeeper checks. This tap offers an explicit sideloading path and checks SHA-256 hashes, without notarization or PGP signature verification.</p>
      <p>Hashes verify downloaded bytes, not publisher identity. A compromised upstream account or build can publish malicious software with valid hashes. Clearing quarantine reduces macOS download protection. Weekly checks publish tap updates; they do not automatically upgrade your installed app.</p>
      <p><a href="https://doublecmd.sourceforge.io/">Upstream website</a> · <a href="https://github.com/doublecmd/doublecmd">Upstream GitHub</a> · <a href="https://github.com/Homebrew/homebrew-cask/blob/ef0757f8d941d65fca367e6f135c56bad820b1ae/Casks/d/double-commander.rb">Legacy official cask</a> · <a href="https://github.com/brozkeff/homebrew-doublecmd">Documentation and source</a></p>
      <p>Original tooling: EUPL-1.2. Double Commander: upstream GPLv2. Inherited Homebrew material retains BSD-2-Clause notices.</p>
      </body></html>
    HTML
  end

  def self.write(data, output, snapshot: nil, channel: 'stable')
    # Render everything before writing so discovery/hash failures cannot change published files.
    files = { CHANNELS.fetch(channel).fetch(:file) => "#{JSON.pretty_generate(data)}\n",
              'Casks/double-commander.rb' => cask(data, snapshot, channel: channel),
              'docs/index.html' => html(data, snapshot, channel: channel) }
    files['snapshot.json'] = "#{JSON.pretty_generate(snapshot)}\n" if snapshot
    files.each do |path, content|
      target = File.join(output, path)
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, content)
    end
  end

  def self.update_channel(channel, failures: nil)
    old_path = File.join(ROOT, CHANNELS.fetch(channel).fetch(:file))
    old = File.exist?(old_path) ? JSON.parse(File.read(old_path)) : nil
    release = latest(all(channel), channel)
    selected = assets(release)
    if old
      comparison = version(release, channel).split('.').map(&:to_i) <=> old.fetch('version').split('.').map(&:to_i)
      raise 'Refusing downgrade' if comparison.negative?

      if comparison.zero?
        unchanged = old['tag'] == release['tag_name'] && selected.all? do |arch, asset|
          saved = old['assets'].fetch(arch)
          %w[id name updated_at size digest].all? { |key| saved[key] == asset[key] } && saved['url'] == asset['browser_download_url']
        end
        raise 'Published release assets changed; investigate manually' unless unchanged

        return old
      end
    end
    manifest(release, channel)
  rescue StandardError => e
    raise unless old

    failures << "#{channel}: #{e.message}" if failures && !e.is_a?(MissingAsset)
    warn "Keeping #{channel} #{old['version']}: #{e.message}"
    old
  end

  def self.run(argv)
    command = argv.shift
    options = { limit: 10, output: File.join(ROOT, 'tmp', 'preview'), channel: 'stable' }
    OptionParser.new do |p|
      p.on('--limit N', Integer) { |v| options[:limit] = v }
      p.on('--last N', Integer) { |v| options[:last] = v }
      p.on('--tag TAG') { |v| options[:tag] = v }
      p.on('--channel CHANNEL', CHANNELS.keys) { |v| options[:channel] = v }
      p.on('--output DIR') { |v| options[:output] = v }
      p.on('--check') { options[:check] = true }
    end.parse!(argv)
    raise 'Unexpected arguments' unless argv.empty?
    raise 'Counts must be positive' if options.values_at(:limit, :last).compact.any? { |n| n <= 0 }

    case command
    when 'list', 'render'
      channel = options[:channel]
      releases = all(channel).sort_by { |r| r.fetch('published_at') }.reverse
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
        write(manifest(release, channel), options[:output], channel: channel)
      elsif options[:last]
        rows = releases.first(options[:last]).each_with_index.map do |r, index|
          directory = "release-#{index + 1}"
          begin
            write(manifest(r, channel), File.join(options[:output], directory), channel: channel)
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
      failures = []
      previous = CHANNELS.transform_values do |config|
        path = File.join(ROOT, config.fetch(:file))
        File.exist?(path) ? JSON.parse(File.read(path)) : nil
      end
      stable = update_channel('stable', failures: failures)
      snapshot = update_channel('snapshot', failures: failures)
      changes = { 'stable' => stable, 'snapshot' => snapshot }.reject { |channel, data| data == previous[channel] }
      if changes.empty?
        raise "Release checks failed: #{failures.join('; ')}" unless failures.empty?

        puts 'Already up to date'
        return
      end
      if options[:check]
        changes.each { |channel, data| puts "Would publish #{channel} #{data['version']}" }
      else
        write(stable, ROOT, snapshot: snapshot)
        changes.each { |channel, data| puts "Published #{channel} #{data['version']} locally" }
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
