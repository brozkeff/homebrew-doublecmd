---
status: Accepted
date: 2026-09-28
---
# Single cask release channels

## Context and Problem Statement

Users want opt-in snapshot builds and a return to the latest stable release through normal Homebrew upgrades. Two cask tokens would target the same `Double Commander.app` and require an uninstall to switch.

## Decision Outcome

Keep one `double-commander` cask. The `HOMEBREW_DOUBLE_COMMANDER_CHANNEL` environment setting selects stable (default) or snapshot metadata when Homebrew loads it. Weekly publishing verifies and stores each channel independently. Numeric snapshot revisions and stable versions can move forward within their own channels; switching back to stable intentionally replaces a snapshot with the current stable version, even if that is a downgrade.

This supersedes [0006 Deferred snapshot channel](0006%20Deferred%20snapshot%20channel.md). Users retain one Homebrew installation and one app path. They must back up configuration before downgrading across channels.
