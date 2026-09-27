# Double Commander for macOS

An unofficial Homebrew tap for native Apple Silicon and Intel builds of Double Commander. The [legacy official cask](https://github.com/Homebrew/homebrew-cask/blob/ef0757f8d941d65fca367e6f135c56bad820b1ae/Casks/d/double-commander.rb) was disabled on September 1, 2026 for failing Gatekeeper checks. This tap restores a sideloading installation path with pinned SHA-256 hashes and automatic extended-attribute clearing.

[Upstream website](https://doublecmd.sourceforge.io/) · [Upstream GitHub](https://github.com/doublecmd/doublecmd) · [Upstream releases](https://github.com/doublecmd/doublecmd/releases) · [Download site](https://brozkeff.github.io/homebrew-doublecmd/)

## Install and upgrade

Requires macOS 11 or newer and Homebrew. Homebrew's own supported macOS versions may be more restrictive.

```sh
brew tap brozkeff/doublecmd
brew trust --cask brozkeff/doublecmd/double-commander
brew install --cask brozkeff/doublecmd/double-commander

# Later:
brew update
brew upgrade --cask brozkeff/doublecmd/double-commander
```

Use the fully qualified cask name to select this tap. Current Homebrew requires explicit trust for third-party casks; the command above trusts only this cask. Homebrew chooses the package for its running architecture; use native ARM Homebrew on Apple Silicon.

If migrating from an installed official cask, quit Double Commander and uninstall the old cask first, without `--zap`, then install the fully qualified cask above. Ordinary uninstall preserves settings. Back up important configuration before migration.

```sh
brew uninstall --cask double-commander
brew install --cask brozkeff/doublecmd/double-commander
```

Quit the app before upgrades. The cask runs `/usr/bin/xattr -cr` on the installed app after every install, reinstall, or upgrade, before you launch it. It respects `--appdir`; the default target is `/Applications/Double Commander.app`. Attribute-clearing failures fail installation.

For a manual upstream installation or recovery, run before launching:

```sh
xattr -cr "/Applications/Double Commander.app/"
```

Uninstall with `brew uninstall --cask brozkeff/doublecmd/double-commander`. Adding `--zap` removes `~/Library/Caches/doublecmd`, matching the historical cask. It does not remove all application settings.

## Trust and automatic updates

Weekly checks run Monday at 06:17 UTC. The updater selects the highest numeric non-prerelease version, discovers both architecture DMGs without constructing filenames, downloads them, and pins their SHA-256 hashes. If an architecture is missing, matches are ambiguous, or validation fails, published files stay unchanged. New releases are committed automatically using Conventional Commits. A manual workflow dispatch can refresh sooner.

SHA-256 checks establish that downloaded bytes match the tap's committed hash. They do **not** authenticate the publisher. We do not verify PGP signatures, notarization, independently reproduced builds, or malware scans. A compromised upstream account or build pipeline can publish malicious binaries with valid hashes; the automatic updater could then publish those hashes. Compromised tap credentials could also modify packages or installation hooks. GitHub asset digests use the same upstream trust boundary and are not independent authentication.

`xattr -cr` recursively removes **all** extended attributes, including quarantine. This reduces macOS download protection for this app. Install only if you accept this sideloading behavior. Weekly polling limits cost and frequency, not authenticity risk. Publishing updates does not install them on your Mac: you choose when to run Homebrew upgrades unless you have separate upgrade automation.

The tap rejects downgrades and changed asset identities or metadata at a previously published version. Such changes need manual investigation. An upstream replacement that preserves all observed metadata cannot be detected by a no-download poll; the committed hash still prevents changed bytes from installing successfully.

## Run locally

Release commands use Ruby's standard libraries. Tests and linting use locked development gems (Minitest and RuboCop); CI caches these with ruby/setup-ruby. Homebrew Ruby works locally. `GITHUB_TOKEN` is optional locally; it raises the GitHub API rate limit. Tokens are sent only to `api.github.com`.

```sh
bundle install
bundle exec ruby -Itest test/releases_test.rb
bundle exec rubocop
ruby scripts/releases.rb list --limit 10
ruby scripts/releases.rb render --tag v1.2.8 --output tmp/v1.2.8
ruby scripts/releases.rb render --last 10 --output tmp/releases
ruby scripts/releases.rb update --check
ruby scripts/releases.rb update
```

Open `tmp/releases/index.html` for the ten most recently published non-draft releases, including prereleases. Each eligible preview has its own cask, manifest, and page; incomplete or unsupported releases display an explanation. Previews do not change the production tap. Asset downloads are cached under `.cache/`; these and `tmp/` are ignored by Git. `--check` may populate the cache but does not modify tracked files.

Production files are `release.json`, `Casks/double-commander.rb`, and `docs/index.html`. Edit the renderer rather than generated files. A changed archive format or unrecognized architecture name needs a reviewed matcher update. Local previews do not install or launch Double Commander.

## Validation and publishing

Local offline tests compare generated 1.2.8 cask fields with the exact historical official cask after removal of `disable!`, including both original hashes. The added attribute-clearing hook is tested separately. Tests also cover discovery and rendering. To verify real historical downloads locally, run the 1.2.8 render command above and compare its `release.json` hashes with the official fixture.

The release workflow runs on Ubuntu, downloads binaries only for a changed candidate, and skips unchanged commits and scheduled deployments. Tests and RuboCop run **only locally**; GitHub Actions never launches test or macOS runner jobs. Pages is deployed explicitly after automated commits because bot commits do not trigger another workflow. Enable GitHub Pages with **GitHub Actions** as its source and allow Pages deployment from `master`. The repo must permit Actions to write contents.

Installation smoke checks are local only. Use current Homebrew: the cask uses its declarative `postflight_steps` API. Local packaging checks can inspect cask parsing and audit both architecture branches without installing the app. Only manually install, reinstall, or upgrade on a machine where you intend to run Double Commander.

Homebrew auditing skips only `sha256_no_check_if_unversioned`: that check treats literal URLs as unversioned even when they point to a fixed release asset. We retain explicit discovered URLs and mandatory hashes rather than replacing them with filename templates or `:no_check`.

## Future snapshots

A future opt-in `double-commander@snapshot` cask can track numeric revisions in [public snapshot releases](https://github.com/doublecmd/snapshots/releases), including [revision 13524](https://github.com/doublecmd/snapshots/releases/tag/13524). Those releases provide ARM and Intel DMGs directly. It should conflict with the stable cask because both install the same app, and reuse hash verification and attribute clearing. Snapshot installation is not implemented here; no separate Git branch or Actions artifact access is needed.

## Licenses

Original build/update scripts are **EUPL-1.2**; see [LICENSE](LICENSE). The installed Double Commander software is independently licensed under **GNU GPL version 2**; see [upstream license](https://github.com/doublecmd/doublecmd/blob/master/LICENSE.md). Inherited Homebrew cask material retains its BSD-2-Clause notices. See [NOTICE](NOTICE) for provenance. Installing upstream GPL software does not relicense this repository's scripts.

## Decisions

Short [ADRs](docs/decisions/) record release discovery, checksum trust, weekly automation, minimal Ruby tooling, licensing, and the deferred snapshot channel. [Contribution guidelines](CONTRIBUTING.md) cover maintenance conventions.
