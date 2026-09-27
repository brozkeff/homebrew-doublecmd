# Contributing

Use `master` and Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`). Original tooling contributions use EUPL-1.2. Preserve upstream license notices and historical fixtures.

Run `bundle install`, `bundle exec ruby -Itest test/releases_test.rb`, and `bundle exec rubocop` before submitting changes. Keep routine tests offline. Run historical downloads explicitly when changing discovery or hash handling. Do not regenerate fixtures merely to make a failed baseline test pass. Maintain short ADRs for significant decisions. Actions must use latest stable releases pinned to exact commit SHAs; review the weekly Dependabot updates.

Keep the pipeline small: Ruby standard libraries, one Ubuntu publishing job, no daily downloads or macOS installation on scheduled refreshes. Do not weaken hashes to `:no_check`, select the first ambiguous asset, enable unsigned snapshot installs in the stable cask, or silently accept replaced release assets.

Report tap packaging and updater problems here; report application behavior to upstream Double Commander. For security concerns, avoid posting tokens or private logs in public issues.
