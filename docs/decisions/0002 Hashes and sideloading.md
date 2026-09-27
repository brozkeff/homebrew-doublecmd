---
status: Accepted
date: 2026-09-27
---
# Hashes and sideloading

## Context and Problem Statement

The official cask was disabled for failing Gatekeeper checks. Users require an explicit sideloading path.

## Decision Outcome

Compute SHA-256 for upstream DMGs, compare available GitHub digests, and pin hashes in the cask. Remove `disable!` and run mandatory `xattr -cr` after every install or upgrade, respecting the application directory. Reject unexpected replacement of published assets. Do not require notarization or PGP verification.

Consequence: hashes are byte integrity, not publisher authentication. Compromised upstream builds or publishing can propagate malicious binaries with valid hashes. Clearing all extended attributes reduces macOS quarantine protection. Explain this in the README and site.
