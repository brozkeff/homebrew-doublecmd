# SPDX-License-Identifier: EUPL-1.2
require 'json'
data = JSON.parse(File.read(File.expand_path('../tmp/v1.2.8/release.json', __dir__)))
expected = {
  'arm' => '7432cf00b9d111730b26ca69d546d40408ca1b8e7ac31253fbc68780799120f0',
  'intel' => '2cb6d149fa9b4c993ee6b9323224c26b90181f1bf9c2277049678ee08be3c88d'
}
abort 'Expected version 1.2.8' unless data['version'] == '1.2.8'
expected.each { |arch, hash| abort "#{arch} hash differs from official cask" unless data['assets'].fetch(arch).fetch('sha256') == hash }
puts 'Both 1.2.8 downloads match the historical official hashes'
