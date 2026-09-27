---
status: Accepted
date: 2026-09-27
---
# Separate tooling and upstream licenses

## Context and Problem Statement

This repository provides original tooling, inherits Homebrew cask material, and downloads independently licensed upstream software.

## Decision Outcome

License original tooling under EUPL-1.2. Preserve BSD-2-Clause notices for Homebrew-derived material and the exact historical fixture. Document Double Commander's separate upstream GPLv2 license and link its license file. Download binaries directly from upstream rather than mirroring them.

Consequence: the repository license does not replace third-party licenses. Keep NOTICE and prominent upstream and legacy-cask links.
