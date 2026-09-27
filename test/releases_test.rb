# SPDX-License-Identifier: EUPL-1.2
require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require_relative '../scripts/releases'

class CaskFields
  attr_reader :fields, :hooks

  def initialize(architecture)
    @architecture = architecture
    @fields = {}
    @hooks = []
  end

  def cask(_name, &) = instance_eval(&)

  def arch(values = nil)
    values ? @arch = values.fetch(@architecture.to_sym) : @arch
  end

  def version(value = nil)
    value ? @fields[:version] = value : @fields[:version]
  end

  def sha256(values) = @fields.[]=(:sha256, values.fetch(@architecture.to_sym))

  def on_arm(&)
    instance_eval(&) if @architecture == 'arm'
  end

  def on_intel(&)
    instance_eval(&) if @architecture == 'intel'
  end

  def url(value)
    @fields[:url] = value unless @livecheck
  end

  def livecheck(&)
    @livecheck = true
    instance_eval(&)
    @livecheck = false
  end

  def strategy(value) = @fields.[]=(:livecheck_strategy, value)
  def postflight_steps(&) = instance_eval(&)
  def run(path, **options) = @hooks << [path, options]

  def method_missing(name, *args)
    return @arch if name == :arch

    @fields[name] = args
  end

  def respond_to_missing?(_name, _include_private = false)
    true
  end
end

class ReleasesTest < Minitest::Test
  def setup
    @release = JSON.parse(File.read(File.join(__dir__, 'fixtures/v1.2.8.json')))
  end

  def data
    hashes = { 'arm' => '7432cf00b9d111730b26ca69d546d40408ca1b8e7ac31253fbc68780799120f0',
               'intel' => '2cb6d149fa9b4c993ee6b9323224c26b90181f1bf9c2277049678ee08be3c88d' }
    { 'version' => '1.2.8', 'tag' => 'v1.2.8', 'release_url' => @release['html_url'],
      'assets' => Releases.assets(@release).transform_values { |a| { 'url' => a['browser_download_url'], 'sha256' => hashes.fetch(Releases::ARCHES.find { |_k, p| a['name'].match?(p) }.first) } } }
  end

  def test_official_baseline_for_both_architectures
    official = File.read(File.join(__dir__, 'fixtures/official-double-commander.rb')).lines.reject do |line|
      line.strip.start_with?('disable!')
    end.join
    %w[arm intel].each do |architecture|
      expected = CaskFields.new(architecture)
      expected.instance_eval(official)
      actual = CaskFields.new(architecture)
      actual.instance_eval(Releases.cask(data))
      assert_equal expected.fields, actual.fields
      assert_equal [['/usr/bin/xattr', { args: ['-cr', '{{appdir}}/Double Commander.app'], must_succeed: true }]], actual.hooks
      refute_includes Releases.cask(data), 'disable!'
    end
  end

  def test_numeric_order_and_prerelease_filter
    candidates = %w[v1.2.9 v1.2.10 v2.0.0].map { |tag| { 'tag_name' => tag, 'prerelease' => tag == 'v2.0.0' } }
    assert_equal 'v1.2.10', Releases.latest(candidates)['tag_name']
    assert_equal 'v1.2.9', Releases.latest(candidates.map { |r| r.merge('draft' => r['tag_name'] == 'v1.2.10') })['tag_name']
  end

  def test_arbitrary_names_and_architecture_aliases
    @release['assets'] =
      [{ 'name' => 'Mac-arm64-build.dmg', 'state' => 'uploaded' }, { 'name' => 'Other-amd64.dmg', 'state' => 'uploaded' }]
    assert_equal %w[arm intel], Releases.assets(@release).keys
  end

  def test_missing_and_ambiguous_assets
    @release['assets'] = []
    assert_raises(Releases::MissingAsset) { Releases.assets(@release) }
    @release['assets'] = [{ 'name' => 'a.arm64.dmg', 'state' => 'uploaded' }] * 2
    assert_raises(RuntimeError) { Releases.assets(@release) }
  end

  def test_incomplete_latest_waits_without_writing
    incomplete = published_release.merge('tag_name' => 'v99.0.0', 'assets' => [])
    Releases.stub(:all, [incomplete]) do
      assert_output(/Waiting for complete release/) { Releases.run(['update']) }
    end
  end

  def test_pagination
    page = 0
    fetch = lambda do |_url|
      page += 1
      JSON.generate(page == 1 ? Array.new(100) { { 'tag_name' => 'v1.0.0' } } : [{ 'tag_name' => 'v1.2.8' }])
    end
    Releases.stub(:get, fetch) { assert_equal 101, Releases.all.length }
    assert_equal 2, page
  end

  def test_download_hash_and_digest_failure
    Dir.mktmpdir do |dir|
      payload = 'test binary'
      @release['assets'] = %w[arm64 x64].each_with_index.map do |arch, index|
        { 'name' => "mac.#{arch}.dmg", 'id' => index, 'state' => 'uploaded', 'size' => payload.bytesize,
          'updated_at' => 'now', 'digest' => "sha256:#{Digest::SHA256.hexdigest(payload)}",
          'browser_download_url' => "https://github.com/doublecmd/doublecmd/releases/download/v1.2.8/mac.#{arch}.dmg" }
      end
      Releases.stub(:get, payload) do
        # Use unique fixture asset identities to avoid colliding with real cached downloads.
        @release['assets'].each { |a| a['id'] = "test-#{File.basename(dir)}-#{a['id']}" }
        result = Releases.manifest(@release)
        assert_equal Digest::SHA256.hexdigest(payload), result['assets']['arm']['sha256']
        @release['assets'][0]['digest'] = 'sha256:wrong'
        assert_raises(RuntimeError) { Releases.manifest(@release) }
      end
    end
  end

  def test_site_and_cask_agree
    assert_includes Releases.html(data), data['assets']['arm']['url']
    assert_includes Releases.html(data), data['assets']['intel']['sha256']
    Dir.mktmpdir do |dir|
      Releases.write(data, dir)
      assert_equal data, JSON.parse(File.read(File.join(dir, 'release.json')))
      assert_equal Releases.cask(data), File.read(File.join(dir, 'Casks/double-commander.rb'))
    end
  end

  def published_release
    saved = JSON.parse(File.read(File.join(Releases::ROOT, 'release.json')))
    { 'tag_name' => saved['tag'], 'html_url' => saved['release_url'],
      'assets' => saved['assets'].values.map do |asset|
        asset.merge('state' => 'uploaded', 'browser_download_url' => asset['url'])
      end }
  end

  def test_unchanged_update_does_not_download
    Releases.stub(:all, [published_release]) do
      Releases.stub(:manifest, ->(_) { flunk 'Unchanged release should not download' }) do
        assert_output("Already up to date\n") { Releases.run(['update', '--check']) }
      end
    end
  end

  def test_downgrade_and_replaced_asset_are_rejected
    Releases.stub(:all, [@release]) { assert_raises(RuntimeError) { Releases.run(['update']) } }
    changed = published_release
    changed['assets'][0]['id'] += 1
    Releases.stub(:all, [changed]) { assert_raises(RuntimeError) { Releases.run(['update']) } }
  end

  def test_failed_candidate_keeps_published_files
    paths = %w[release.json Casks/double-commander.rb docs/index.html].map { |p| File.join(Releases::ROOT, p) }
    before = paths.map { |p| File.read(p) }
    newer = published_release.merge('tag_name' => 'v99.0.0')
    Releases.stub(:all, [newer]) do
      Releases.stub(:manifest, ->(_) { raise 'Digest mismatch' }) do
        assert_raises(RuntimeError) { Releases.run(['update']) }
      end
    end
    assert_equal(before, paths.map { |p| File.read(p) })
  end

  def test_ten_release_previews_and_incomplete_release
    releases = Array.new(10) do |i|
      @release.merge('tag_name' => "v1.2.#{i}", 'published_at' => format('2026-09-%02dT00:00:00Z', i + 1))
    end
    render = lambda do |release|
      raise 'Missing Intel package' if release['tag_name'] == 'v1.2.0'

      data.merge('version' => Releases.version(release))
    end
    Dir.mktmpdir do |dir|
      Releases.stub(:all, releases) do
        Releases.stub(:manifest, render) { Releases.run(['render', '--last', '10', '--output', dir]) }
      end
      assert_equal 9, Dir.glob(File.join(dir, 'release-*/release.json')).length
      assert_includes File.read(File.join(dir, 'index.html')), 'Missing Intel package'
    end
  end
end
