---
status: Superseded: by 0007 Local-only testing and lean publishing.md
date: 2026-09-27
---
# Minimal Ruby tooling and historical regression

## Context and Problem Statement

Local release previews and a faithful historical baseline are required without a framework or a site build system.

## Decision Outcome

Use one Ruby standard-library release script, a shared manifest, and static HTML. Offer list, tag preview, last-ten previews, update, and read-only check commands. Use Minitest and RuboCop as development dependencies only. Compare evaluated 1.2.8 cask fields against the exact official fixture with `disable!` removed, and test the extra attribute-clearing hook separately.

Consequence: previews may download multiple binaries; ordinary CI stays offline except for a changed release. No app rebuilds, mirrors, JavaScript framework, or speculative snapshot infrastructure.
