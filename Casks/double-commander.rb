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
    version "13576"
    sha256 arm:   "c4e0bda75d4910f3b3616c9076d5208d18d584b8106be4c6f09ca07694ac9a15",
           intel: "19bfc72b5a32ec7046e599d50af63771f5e96531ad12251d5bf0bbc3f3b72a67"

    on_arm do
      url "https://github.com/doublecmd/snapshots/releases/download/13576/doublecmd-1.3.0-13576.cocoa.aarch64.dmg"
    end
    on_intel do
      url "https://github.com/doublecmd/snapshots/releases/download/13576/doublecmd-1.3.0-13576.cocoa.x86_64.dmg"
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
