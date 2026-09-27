---
status: Accepted
date: 2026-09-27
---
# Weekly publishing and repository conventions

## Context and Problem Statement

Releases are infrequent. Daily downloads and routine macOS jobs would waste time and CI resources.

## Decision Outcome

Use `master`, Conventional Commits, and weekly Monday 06:17 UTC checks with manual dispatch. A single Ubuntu job commits validated updates and explicitly deploys Pages. Skip unchanged scheduled deployments; run installation smoke checks manually. Pin latest stable Actions to commit SHAs and use Dependabot for ongoing review of updates.

Consequence: updates can lag by a week. Automatic tap publication is separate from users choosing to upgrade installed software. Dependency updates remain reviewable PRs.
