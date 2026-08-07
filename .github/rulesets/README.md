# Repository rulesets

GitHub rulesets for `main` and `release/*` enforce:

- **No direct pushes** — changes must land via pull request (`pull_request` rule).
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

The script creates or updates rulesets by name. If GitHub rejects `merge_queue` or `bypass_actors` via API, it retries without those fields and prints what to finish in the UI.

## One-time UI steps (if API apply skips them)

### 1. Enable merge queue on `main`

GitHub may reject the `merge_queue` rule via REST on some accounts. If **Merge when ready** is not available after applying:

1. Open [Repository rules](https://github.com/Ewynman/spot-ios-app/settings/rules).
2. Edit **Protect main (merge queue + CI)**.
3. Add rule **Require merge queue** with:
   - Require all queue entries to pass required checks: **on**
   - Status check timeout: **90** minutes
   - Merge method: **Merge commit** (matches current repo practice)
4. Save.

`ci.yml` already listens for `merge_group` so queue checks run once this is enabled.

### 2. Allow deploy workflows to push build numbers

`deploy.yml` and `testflight.yml` push automated build-number commits to protected branches. Add a bypass so `GITHUB_TOKEN` is not blocked:

1. Edit each ruleset (**main** and **release branches**).
2. **Bypass list → Add bypass → GitHub Actions**.
3. Mode: **Always**.
4. Save.

Without this bypass, Firebase/TestFlight deploys fail when pushing `[skip ci]` build bumps.

## Current live rulesets

After apply, confirm at: https://github.com/Ewynman/spot-ios-app/settings/rules
