---
status: Accepted
date: 2026-09-27
---
# Dynamic release discovery

## Context and Problem Statement

Upstream filenames may change. GitHub publication order is not version order, and macOS assets may arrive separately.

## Decision Outcome

Read paginated release metadata, select the highest numeric non-prerelease version, and require exactly one uploaded DMG for each architecture. Publish explicit URLs and hashes together; incomplete releases keep the previous version. Prefer this over filename templates or network discovery during Homebrew installation.

Consequence: new packaging or unknown architecture labels require a reviewed matcher change.
