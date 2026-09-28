---
status: 'Superseded: by 0009 Single cask release channels.md'
date: 2026-09-27
---
# Deferred snapshot channel

Superseded by [0009 Single cask release channels](0009%20Single%20cask%20release%20channels.md).

## Context and Problem Statement

Snapshot release 13524 provides public ARM and Intel DMGs, but stable installation is the current goal.

## Decision Outcome

Defer implementation. If requested later, add `double-commander@snapshot` in the same tap using public snapshot releases and numeric revision ordering. Declare mutual conflict with stable because both install the same app, and reuse hash verification and attribute clearing. Avoid a separate Git branch and Actions artifact downloads.

Consequence: stable tooling contains no snapshot scaffolding or automatic snapshot installation.
