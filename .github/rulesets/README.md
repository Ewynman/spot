# Repository rulesets

GitHub rulesets for `main` and `release/*` enforce:

- **No direct pushes for non-admins** — changes must land via pull request (`pull_request` rule).
- **Required CI** — the `PR Validation` check from `.github/workflows/ci.yml` must pass.
- **No force-push** — `non_fast_forward` blocks history rewrites.
- **`main` only: merge queue** — use **Merge when ready** so merges go through the queue (see manual step below).

## Files

| File | Branches | Notes |
|------|----------|-------|
| `main.json` | `main` | Includes merge-queue config (may require a UI step; see below). |
| `release-branches.json` | `release/*` | PR + CI only (merge queue is not supported on wildcard refs). |

## Apply / update

From repo root (requires `gh` authenticated as a repo admin):

```bash
./scripts/apply-github-rulesets.sh
```

The script creates or updates rulesets by name. If GitHub rejects `merge_queue` via API, it retries without that field and prints what to finish in the UI.

## Bypass actors (user-owned repository)

This repository is owned by a **user account**, not an organization. GitHub rejects the **GitHub Actions** integration (`actor_id` 15368) as a ruleset bypass on user-owned repos:

> Actor GitHub Actions integration must be part of the ruleset source or owner organization

`bypass_actors` therefore uses **Repository role: Admin** (`actor_id` 5) so the owner can emergency-push if needed.

Deploy workflows **must not** rely on `GITHUB_TOKEN` pushing bump commits to protected branches, and cannot use repository Actions variables (`GITHUB_TOKEN` lacks admin rights for that API). They allocate build numbers on the unprotected `ci/build-number` branch (`scripts/allocate-ci-build-number.sh`).

## One-time UI steps (if API apply skips them)

### Enable merge queue on `main`

GitHub may reject the `merge_queue` rule via REST on some accounts. If **Merge when ready** is not available after applying:

1. Open [Repository rules](https://github.com/Ewynman/spot-ios-app/settings/rules).
2. Edit **Protect main (merge queue + CI)**.
3. Add rule **Require merge queue** with:
   - Require all queue entries to pass required checks: **on**
   - Status check timeout: **90** minutes
   - Merge method: **Merge commit** (matches current repo practice)
4. Save.

`ci.yml` already listens for `merge_group` so queue checks run once this is enabled.

## Current live rulesets

After apply, confirm at: https://github.com/Ewynman/spot-ios-app/settings/rules
