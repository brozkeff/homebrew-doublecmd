# SPDX-License-Identifier: EUPL-1.2
# Derived from Homebrew/homebrew-cask; see NOTICE and test/fixtures/HOMEBREW-LICENSE.
cask "double-commander" do
  case ENV.fetch("HOMEBREW_DOUBLE_COMMANDER_CHANNEL", "stable")
  when "stable"
    version "1.2.9"
    sha256 arm:   "6d615ae9d87fe60fed4efbb32fa83b5c21f2bfc007836f3f12e60e599d3447e8",
           intel: "5a60a5efa31b4438512aabf0213c2c307dd910b3a6661f70da4dfbcfa6730578"

    on_arm do
      url "https://github.com/doublecmd/doublecmd/releases/download/v1.2.9/doublecmd-1.2.9.cocoa.aarch64.dmg"
    end
    on_intel do
      url "https://github.com/doublecmd/doublecmd/releases/download/v1.2.9/doublecmd-1.2.9.cocoa.x86_64.dmg"
    end

    livecheck do
      url "https://github.com/doublecmd/doublecmd/releases/latest"
      strategy :github_latest

    end
  when "snapshot"
    version "13549"
    sha256 arm:   "6d771e5d736c857efef3ba6a9d909b6b29622b3c3d9d4a11bf412e44cfbffb6b",
           intel: "34d414fefa23b244d1eb100f25e98e9c253191d71e0bd6d2191def4b2b507440"

    on_arm do
      url "https://github.com/doublecmd/snapshots/releases/download/13549/doublecmd-1.3.0-13549.cocoa.aarch64.dmg"
    end
    on_intel do
      url "https://github.com/doublecmd/snapshots/releases/download/13549/doublecmd-1.3.0-13549.cocoa.x86_64.dmg"
    end

    livecheck do
      url "https://github.com/doublecmd/snapshots/releases"
      strategy :github_releases
      regex(/^(\d+)$/)
    end
  else
    raise "Set HOMEBREW_DOUBLE_COMMANDER_CHANNEL to stable or snapshot"
  end

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
