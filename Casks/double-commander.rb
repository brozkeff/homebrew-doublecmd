# SPDX-License-Identifier: EUPL-1.2
# Derived from Homebrew/homebrew-cask; see NOTICE and test/fixtures/HOMEBREW-LICENSE.
cask "double-commander" do
  case ENV.fetch("HOMEBREW_DOUBLE_COMMANDER_CHANNEL", "stable")
  when "stable"
    version "1.2.10"
    sha256 arm:   "890bf553059d82150b185c0cb7a71ba0de55350d66a0329d941acafb21452470",
           intel: "58ff7ed995bed778599bb242aa0f6a922262b1f6269521a4492329557de8f967"

    on_arm do
      url "https://github.com/doublecmd/doublecmd/releases/download/v1.2.10/doublecmd-1.2.10.cocoa.aarch64.dmg"
    end
    on_intel do
      url "https://github.com/doublecmd/doublecmd/releases/download/v1.2.10/doublecmd-1.2.10.cocoa.x86_64.dmg"
    end

    livecheck do
      url "https://github.com/doublecmd/doublecmd/releases/latest"
      strategy :github_latest

    end
  when "snapshot"
    version "13625"
    sha256 arm:   "383c481e392116737304d1eb0e7483cc384760127aa1b10ded63afa48ac73ee3",
           intel: "37a027a1d8fa1caf72bfa2a58c0df0037070725885f3fe408843c2dbb8b7e8ee"

    on_arm do
      url "https://github.com/doublecmd/snapshots/releases/download/13625/doublecmd-1.3.0-13625.cocoa.aarch64.dmg"
    end
    on_intel do
      url "https://github.com/doublecmd/snapshots/releases/download/13625/doublecmd-1.3.0-13625.cocoa.x86_64.dmg"
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
