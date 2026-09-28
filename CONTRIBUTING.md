# Contributing

Use `master` and Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`). Original tooling contributions use EUPL-1.2. Preserve upstream license notices and historical fixtures.

Run `bundle install`, `bundle exec ruby -Itest test/releases_test.rb`, and `bundle exec rubocop` locally before submitting changes. GitHub Actions runs no tests. Keep routine tests offline. Run historical downloads explicitly when changing discovery or hash handling. Do not regenerate fixtures merely to make a failed baseline test pass. Maintain short ADRs for significant decisions. Actions must use latest stable releases pinned to exact commit SHAs; review their versions when maintaining the workflow.

The repository's Actions policy allows only the pinned SHAs in the publishing workflow and the `actions/upload-artifact` SHA used by `upload-pages-artifact`. Update the repository's selected-Actions allowlist whenever those pins change; retain mandatory SHA pinning.

Keep the pipeline small: Ruby standard libraries, one Ubuntu publishing job, no daily downloads or macOS installation on scheduled refreshes. Do not weaken hashes to `:no_check`, select the first ambiguous asset, select snapshots without explicit opt-in, or silently accept replaced release assets.

Report tap packaging and updater problems here; report application behavior to upstream Double Commander. For security concerns, avoid posting tokens or private logs in public issues.
