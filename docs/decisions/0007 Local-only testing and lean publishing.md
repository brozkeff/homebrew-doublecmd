---
status: Accepted
date: 2026-09-28
---
# Local-only testing and lean publishing

## Context and Problem Statement

The first implementation added hosted test and macOS installation workflows. These are unnecessary for an infrequently updated tap and macOS runners are costly. This supersedes [0003](0003%20Weekly%20publishing%20and%20repository%20conventions.md) and [0004](0004%20Minimal%20Ruby%20tooling%20and%20historical%20regression.md).

## Decision Outcome

Keep one weekly Ubuntu publishing workflow, pinned to exact stable Action SHAs. Run tests, RuboCop, and installation checks only on local machines. The release script itself validates downloaded bytes and fails closed. Keep the 1.2.8 fixtures and local preview commands. Remove hosted test, macOS smoke, and Dependabot workflows.

Consequence: contributors and maintainers must run local checks before publishing code changes. Weekly publishing remains fast and has no macOS runner cost.
