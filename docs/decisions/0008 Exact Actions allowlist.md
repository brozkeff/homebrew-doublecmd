---
status: Accepted
date: 2026-09-28
---
# Exact Actions allowlist

## Context and Problem Statement

The repository initially allowed only local Actions, so Pages deployment could not start. Allowing every external Action would be broader than the publishing workflow needs.

## Decision Outcome

Keep repository Action permissions set to `selected` with mandatory full-SHA pinning. Allow only the exact SHAs used by checkout, configure-pages, upload-pages-artifact, deploy-pages, and the upload-artifact SHA used internally by upload-pages-artifact. Update this allowlist when Action pins change.

Consequence: Pages can deploy with no general permission for third-party Actions; updating a pin also requires a repository settings change.
