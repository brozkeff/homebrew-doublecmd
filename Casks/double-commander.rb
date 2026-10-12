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
    version "13565"
    sha256 arm:   "9871c6e2573db009aa2c842cb9d0e403d96d3b10a4a81a83834850b15fc86840",
           intel: "19af7e0ddf642497d341f5ef187f98ebb0c66ccb63761ee3c5783bbdc2fee533"

    on_arm do
      url "https://github.com/doublecmd/snapshots/releases/download/13565/doublecmd-1.3.0-13565.cocoa.aarch64.dmg"
    end
    on_intel do
      url "https://github.com/doublecmd/snapshots/releases/download/13565/doublecmd-1.3.0-13565.cocoa.x86_64.dmg"
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
