# CI/CD Pipeline

## Purpose

Documents the continuous integration and continuous deployment pipeline for the Spot iOS app.

## Audience

Developers, release owners, and anyone maintaining or troubleshooting the build pipeline.

## Current status

**GitHub Actions** is the active CI/CD system. **Xcode Cloud is disabled** to avoid redundant builds and maintain a single source of truth.

## Details

### CI/CD System: GitHub Actions

The Spot project uses GitHub Actions for continuous integration and deployment. Configuration lives in `.github/workflows/`.

#### Workflows

1. **`ci.yml`** - Pull Request validation (runs on PRs to main)
2. **`deploy.yml`** - Firebase App Distribution deployment / Test ENV (runs on push/merge to main)
3. **`testflight.yml`** - App Store Connect / TestFlight deployment (runs on push to `release/**`)

**Three lanes at a glance:**

| Lane | Trigger | Signing cert secret | Profile secret | Export method | Versioning |
| --- | --- | --- | --- | --- | --- |
| PR validation | `pull_request` → `main` | none | none | n/a (simulator tests) | n/a |
| Firebase Test ENV | `push` → `main` | `FIREBASE_DEV_CERT` | `FIREBASE_PROVISIONING_PROFILE` | `ad-hoc` | build number `+1` |
| TestFlight | `push` → `release/**` | `TESTFLIGHT_APPLE_CERT` | `TESTFLIGHT_APPLE_PROFILE` | `app-store` | version from branch, build number `+1` |

The Firebase and TestFlight signing assets are never swapped: the Ad Hoc profile is only used for Firebase, and the App Store Connect profile is only used for TestFlight. `APPLE_CERTIFICATE_PASSWORD` is the single password used to import both `.p12` files, and `KEYCHAIN_PASSWORD` is the temporary CI keychain password.

#### Main workflow: `ci.yml`

**Triggers:**
- Pull requests to `main`
- Pushes to `main`

**Environment:**
- Runner: macOS 15
- Xcode: Default Xcode on the runner (must support the available simulator runtimes)
- Simulator: iPhone 16 simulator

**Pipeline stages:**

1. **Checkout:** Pull repository code with full history (for diff comparison)
2. **Setup:** Install xcbeautify and jq (for JSON parsing)
3. **Cache:** Restore Swift Package Manager dependencies
4. **API Validation (PR only):** Check for breaking API changes
5. **Documentation Validation (PR only):** Validate documentation updates
6. **Test:** Run SpotTests serially with code coverage enabled
7. **Coverage Validation (PR only):** Enforce 80% coverage on the lines the PR changed
8. **Artifacts:** Upload test results (`.xcresult`) and coverage reports
9. **Summary:** Generate coverage summary in GitHub
10. **PR Comment:** Post validation results as PR comment

**What it validates:**
- All unit tests pass
- No compilation errors
- Code coverage is collected and meets the 80% threshold on the lines the PR changed
- No breaking API changes (or they're documented)
- Documentation updates for significant changes
- Data plane compliance (via DataPlaneGuardTests)

See `.github/workflows/README.md` for detailed workflow documentation.

---

#### Deployment workflow: `deploy.yml`

**Triggers:**
- Push to `main` with at least one non-documentation/non-housekeeping file change
- Manual workflow dispatch

The workflow trigger is not technically gated on the separate CI workflow succeeding. Branch protection and merge policy must enforce validation before code reaches `main`.

Documentation, Markdown, agent configuration, ignore-file, and license-only pushes are filtered out before a workflow run is created. Mixed changes still deploy when they contain any app, test, build, script, backend, or workflow change. Manual dispatch bypasses the push path filter for intentional rebuilds.

**Environment:**
- Runner: macOS 15
- Xcode: Selects Xcode 26.x when installed; otherwise retains the runner default and reports the selected version
- Requires: Apple signing certificates and Firebase credentials

**Pipeline stages:**

1. **Checkout:** Pull repository code with full history
2. **Version Management:** Allocate next build number (`ci/build-number` + local `CURRENT_PROJECT_VERSION` update)
3. **Release Notes:** Resolve the PR associated with the deployed commit and convert its `Changes` section to plain text
4. **Firebase Configuration:** Inject GoogleService-Info.plist from secrets
5. **Supabase Configuration:** Inject and verify staging project credentials
6. **Code Signing:** Install certificates and provisioning profiles
7. **Build:** Archive and export signed IPA
8. **Deploy:** Upload to Firebase App Distribution

**What it does:**
- Allocates the next build via `scripts/allocate-ci-build-number.sh` (unprotected `ci/build-number` / `BUILD_NUMBER`, floored by `CURRENT_PROJECT_VERSION` in the checked-out project)
- **Persists the allocated number before building** (prevents duplicate Firebase build numbers when upload succeeds but a later step fails)
- Does **not** push bump commits to `main` / `release/*` — `GITHUB_TOKEN` cannot bypass those rulesets, and cannot use the repository Actions variables API either
- Pins Firebase-distributed internal builds to staging Supabase project `aeurigbbohyxvtsfiyul`; the workflow fails if another project URL is embedded
- Defines `INTERNAL_TESTING` through the Spot target's `SPOT_DISTRIBUTION_CONDITION` setting; it is not applied to Swift Package targets
- Builds signed IPA for distribution
- Generates concise release notes from the associated merged PR title and `Changes` section
- Removes Markdown, automated PR metadata, testing details, and checklist boilerplate because Firebase App Distribution displays release notes as plain text
- Uploads to Firebase App Distribution with testers group
- Skips re-deploy on legacy bump commits (`Bump build number to … [skip ci]`)
- Skips documentation and repository-maintenance-only pushes so they do not increment the build number or publish an unchanged IPA

**Required secrets:**
- `GOOGLE_SERVICE_INFO_PLIST_BASE64` - Firebase GoogleService-Info.plist file (base64 encoded)
- `FIREBASE_APP_ID` - Firebase iOS App ID
- `FIREBASE_SERVICE_ACCOUNT_JSON` - Firebase service account credentials (raw JSON)
- `FIREBASE_DEV_CERT` - Apple Distribution certificate (.p12, base64 encoded). Despite the name, this is the distribution cert used for CI signing.
- `APPLE_CERTIFICATE_PASSWORD` - Password used when exporting the .p12
- `FIREBASE_PROVISIONING_PROFILE` - Ad Hoc provisioning profile (.mobileprovision, base64 encoded)
- `KEYCHAIN_PASSWORD` - Temporary CI keychain password
- `SUPABASE_STAGING_URL` / `SUPABASE_STAGING_ANON_KEY` - Optional staging overrides; the committed staging publishable configuration is used when absent

Export options template: `.github/workflows/ExportOptions-Firebase.plist` (`method = ad-hoc`, `signingCertificate = Apple Distribution`). The provisioning profile name is injected at build time after decoding `FIREBASE_PROVISIONING_PROFILE`.

See [firebase-distribution-setup.md](firebase-distribution-setup.md) for detailed setup instructions.

---

#### Deployment workflow: `testflight.yml`

**Triggers:**
- Push to a `release/**` branch
- Manual workflow dispatch (from a `release/**` branch)

**Environment:**
- Runner: macOS 15
- Requires: Apple signing assets, Firebase config, and App Store Connect API credentials for upload

**Pipeline stages:**

1. **Checkout:** Pull repository code with full history
2. **Resolve version:** Derive `MARKETING_VERSION` from the branch name and allocate the next build via `scripts/allocate-ci-build-number.sh` (`ci/build-number`)
3. **Firebase Configuration:** Inject GoogleService-Info.plist from secrets
4. **Code Signing:** Install `TESTFLIGHT_APPLE_CERT` + `TESTFLIGHT_APPLE_PROFILE` into a temporary keychain
5. **Build:** Archive unsigned, then export an App Store `.ipa`
6. **Artifact:** Upload the `.ipa` as a workflow artifact
7. **Upload:** Send the `.ipa` to App Store Connect / TestFlight via `xcrun altool`
8. **Summary + cleanup:** Emit a build summary and remove temporary keychain/profile/key files

**Versioning rule:**
- The release branch name controls the user-facing version. `release/1.1.0` → `MARKETING_VERSION = 1.1.0`.
- The build number is allocated the same way as the Firebase lane (`ci/build-number`, floored by checked-in `CURRENT_PROJECT_VERSION`); the workflow does not push bump commits to protected `release/*` branches
- The pipeline never bumps `1.1.0` → `1.2.0` automatically. To ship a new version, create a new `release/<version>` branch.
- TestFlight upload does **not** submit the build to App Store Review.

**Required secrets:**
- `GOOGLE_SERVICE_INFO_PLIST_BASE64`
- `TESTFLIGHT_APPLE_CERT` - Apple Distribution certificate (.p12, base64 encoded)
- `APPLE_CERTIFICATE_PASSWORD` - Password used when exporting the .p12
- `TESTFLIGHT_APPLE_PROFILE` - App Store Connect provisioning profile (.mobileprovision, base64 encoded). *(The PRD refers to this as `TESTFLIGHT_PROVISIONING_PROFILE`; the repo's actual secret is `TESTFLIGHT_APPLE_PROFILE`, and we reference the existing name instead of renaming it.)*
- `KEYCHAIN_PASSWORD`

**App Store Connect API secrets (TODO — not yet configured):** the upload step fails with a clear message until these exist. Names follow the PRD's suggested naming:
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8_BASE64` (base64 of the `AuthKey_XXX.p8`)

Create the key at App Store Connect → **Users and Access → Integrations → App Store Connect API**.

Export options template: `.github/workflows/ExportOptions-TestFlight.plist` (`method = app-store`, `signingCertificate = Apple Distribution`).

---

### Xcode Cloud Status

**Xcode Cloud is intentionally disabled** for this repository.

#### Why disabled

- **Single source of truth:** GitHub Actions is the sole CI/CD system
- **Cost management:** Avoids consuming Apple build minutes unnecessarily
- **Consistency:** All builds use the same GitHub Actions configuration
- **Transparency:** CI logs and results are visible in GitHub PR checks
- **Control:** Better control over build triggers, caching, and artifacts

#### How it's disabled

1. **App Distribution:** Workflows disabled in App Store Connect → App Distribution
2. **No workflow files:** Repository contains no `.xcode/` workflow directory
3. **Marker file:** `.xcode-cloud-disabled` at repository root documents this decision

#### Keeping it disabled

Xcode Cloud configuration is managed through App Store Connect. To keep it disabled:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to your app → **App Distribution** → **Xcode Cloud**
3. Ensure all workflows are **disabled** or **deleted**
4. Do not enable "Start Conditions" for:
   - Branch Changes
   - Pull Requests
   - Tag Changes

If Xcode Cloud starts building unexpectedly, check these settings immediately.

### Local vs CI Builds

#### Running tests locally

Developers can run the same tests that CI runs:

```bash
# Get first available iPhone simulator
SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')

# Run unit tests (matches CI)
xcodebuild \
  -scheme SpotTests \
  -destination "id=$SIM_ID" \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -enableCodeCoverage YES \
  test | xcbeautify
```

Or use the convenience variable from project rules:

```bash
SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
BEAUTIFY=$(command -v xcbeautify >/dev/null && echo "xcbeautify" || echo "cat")

xcodebuild -scheme SpotTests -destination "id=$SIM_ID" test | $BEAUTIFY
```

#### CI environment details

- **Xcode version:** Default Xcode on the macos-15 runner
- **Swift version:** Provided by the default Xcode on the runner
- **Simulator:** iPhone 16 (`platform=iOS Simulator,name=iPhone 16`)
- **Execution:** Serial unit-test workers to prevent simulator worker crashes from producing false mass failures
- **Caching:** Swift Package Manager dependencies cached between runs
- **Code coverage:** Always enabled (`-enableCodeCoverage YES`)

### Test Coverage

CI collects code coverage data on every run and **enforces coverage requirements** on pull requests.

The gate measures **changed-line coverage**, not whole-file coverage. The question it asks is "are the lines this PR wrote tested?" rather than "is this entire file well tested?". Whole-file thresholds punish any edit to a legacy low-coverage file — a four-line threading fix in a 341-line Supabase repository would have required retro-covering the whole repository to land, which pushes people toward not touching those files at all.

CI also reports an informational **Spot production scope** metric. It is a
line-weighted summary of production Swift in the `Spot.app` target, including
`Spot/Views/`. The summary intentionally excludes package dependencies, test
targets, and `Spot/Models/Logs/` (declarative log enums). Do not use the root
`xccov` `lineCoverage` value: that aggregate mixes Spot code with linked
Firebase, Supabase, and transitive package targets and therefore produces a
misleadingly low percentage.

**Coverage Requirements:**
- **80% of the executable lines a PR adds or modifies** must be covered
- Applies to in-scope files under `Spot/` (excluding Views and `Models/Logs`; skips pure renames). Informational whole-file metrics still include Views.
- Scope rules live in `scripts/coverage_scope.py`
- Extract pure view logic into `Spot/Utils/` (or ViewModels) so unit tests can hit it; use `SpotUITests` for body/navigation coverage
- Measured using `xcrun xccov` against `.xcresult` bundles
- Validation runs automatically on every PR

**How it works:**
1. Tests run with `-enableCodeCoverage YES`
2. Changed files identified via `git diff --diff-filter=d` and filtered by `coverage_scope.py`
3. Changed line numbers extracted from `git diff -U0` hunk headers
4. Per-line execution counts read with `xcrun xccov view --archive --file`
5. The two are intersected, ignoring non-executable lines (comments, declarations)
6. PR fails if any enforced file covers < 80% of its changed executable lines

**Enforcement floor:** files with fewer than 10 changed executable lines are reported but not enforced. Below roughly that size a single uncovered line swings the percentage so hard that the number stops carrying signal.

**Coverage validation script:**
- Location: `scripts/validate-coverage.sh`
- Usage: `./scripts/validate-coverage.sh <xcresult-path> <base-branch> <threshold> [min-changed-lines]`
- Local uncovered-line helper: `./scripts/show-uncovered-changed-lines.sh <xcresult> [base]`
- Can be run locally before pushing
- Written for bash 3.2 (the default `/bin/bash` on macOS runners), so no associative arrays

**Reading local numbers:** `SpotTests` is app-hosted (`TEST_HOST = Spot.app`), so the app launches during unit tests and picks up incidental coverage that depends on simulator state. A simulator with a signed-in session reaches the feed and location code and reports far higher coverage than CI's clean runner. To reproduce CI numbers locally, run against a freshly created simulator:

```sh
SIM=$(xcrun simctl create "CoverageProbe" "iPhone 16" | tail -1)
xcodebuild -scheme SpotTests -destination "id=$SIM" \
  -enableCodeCoverage YES -resultBundlePath Clean.xcresult test
./scripts/validate-coverage.sh Clean.xcresult origin/main 80 10
xcrun simctl delete "$SIM"
```

**Combined coverage job:** CI also runs an informational `ui_coverage` job with
`-scheme Spot -testPlan Spot` so unit + UI execution contribute to the
production-scope trend. That job is `continue-on-error` and does not gate PRs.

**Coverage reports:**
- Uploaded as artifacts (retained for 7 days)
- Production-scope summary and changed-line gate result posted to the PR
- Raw `xccov` JSON and changed-line details included in the coverage artifact
- Combined unit+UI coverage artifact from the `ui_coverage` job
- Full report available in GitHub Actions logs

**Exemptions:**
- Files with no executable lines changed (e.g., comment or declaration-only edits)
- Files outside production coverage scope (`Spot/Models/Logs/`, tests, packages)
- Code that can only run behind a system permission prompt, which unit tests must not raise
- Can be discussed with team if threshold is impractical for specific cases

### Artifacts

The CI workflow uploads artifacts that are retained for 7 days:

1. **Test results** (`test-results`): `.xcresult` bundles from test runs
   - Can be opened in Xcode for detailed failure analysis
   - Includes all test logs, screenshots, and performance metrics

2. **Coverage reports** (`coverage-reports`): Raw coverage data from ProfileData
   - Can be processed with `xcrun xccov` for analysis
   - Used for future coverage reporting integrations

### Pull Request Checks

When a PR is opened or updated, GitHub Actions automatically:

1. **Validates API stability:** Detects potential breaking changes to public APIs
2. **Validates documentation:** Checks if docs need updates based on code changes
3. **Runs the full unit test suite:** All tests must pass
4. **Validates code coverage:** Enforces 80% minimum on the lines the PR changed
5. **Reports status:** Shows results as checks on the PR
6. **Posts comment:** Summarizes validation results in PR comment
7. **Blocks merge:** If any check fails (when required checks are configured)

**Validation checks (PR only):**

#### 1. API Breaking Change Detection
- **Script:** `scripts/validate-api-changes.sh`
- **Purpose:** Detects changes to public Swift APIs that might break compatibility
- **What it checks:**
  - Removed public functions, classes, structs, enums, protocols
  - Changed function signatures
  - Modified public properties
- **Result:** Warning if breaking changes detected (doesn't block PR, but requires acknowledgment)

#### 2. Documentation Validation
- **Script:** `scripts/validate-documentation.sh`
- **Purpose:** Ensures documentation stays in sync with code changes
- **What it checks:**
  - Service/repository changes → architecture docs
  - ViewModel changes → product docs
  - Database migrations → database-and-rls.md
  - Auth changes → networking-and-auth.md
  - Config changes → configuration.md
- **Result:** Warning with suggestions if docs may need updates

#### 3. Code Coverage Enforcement
- **Script:** `scripts/validate-coverage.sh`
- **Purpose:** Ensures all new/changed code is properly tested
- **What it checks:**
  - Identifies the executable lines each changed production Swift file added or modified
  - Calculates what share of those lines the tests executed
  - Compares against the 80% threshold, for files above the 10-line enforcement floor
- **Result:** Fails PR if any enforced file is below threshold

Developers and reviewers can click on the check to see detailed logs and artifacts.

### Troubleshooting

#### Pipeline failures

If the CI/CD pipeline fails:

1. **Check the Actions tab** in GitHub for detailed logs
2. **Reproduce locally** using the same `xcodebuild` command from ci.yml
3. **Verify Xcode version** matches CI (16.3+)
4. **Check for flaky tests** by running multiple times locally
5. **Review recent changes** for test-breaking modifications
6. See [troubleshooting.md](troubleshooting.md) for common issues

#### Common failure causes

- **Simulator not available:** CI boots simulator before running tests
- **Compilation errors:** Fix in code, tests will automatically re-run
- **Flaky tests:** Add retries or fix race conditions in tests
- **Timeout:** Tests taking too long (>10 minutes is unusual for unit tests)
- **Dependencies:** Clear SPM cache if package resolution fails

#### Xcode Cloud accidentally enabled

If Xcode Cloud starts building again:

1. Check App Store Connect → App Distribution → Xcode Cloud for enabled workflows
2. Disable all workflows or remove start conditions
3. Verify the `.xcode-cloud-disabled` file is still present in the repo
4. Consult with team if there was an intentional policy change

### Deployment Process

**Step-by-step deployment flow:**

1. Developer creates PR with changes
2. **CI validation runs** (`ci.yml`):
   - Changed-line code coverage validated (80% minimum)
   - API changes detected
   - Documentation checked
   - All tests pass
3. PR is reviewed and merged to `main`
4. **Deployment workflow triggers** (`deploy.yml`):
   - Build number auto-increments (e.g., 52 → 53) via `ci/build-number`
   - **Allocated number is persisted before archive/upload** so a failed deploy cannot reuse the same Firebase build number
   - Plain-text release notes generated from the merged PR associated with the deployed commit
   - App is built and signed
   - IPA uploaded to Firebase App Distribution
5. Testers receive notification in Firebase App Distribution

**Build versioning:**
- Marketing version: `1.000` (manual updates for releases)
- Build number: Auto-incremented from the max of `ci/build-number`’s `BUILD_NUMBER` and checked-in `CURRENT_PROJECT_VERSION`
- CI source of truth for shipped builds is `ci/build-number`; the Xcode project is updated in the runner workspace for the archive only

**Deploy safeguards:**
- **Concurrency:** Only one deploy runs at a time (`deploy-firebase-main` group)
- **Path filter:** Documentation and repository-maintenance-only pushes do not create Firebase deploy runs
- **Skip legacy bump commits:** Pushes with message `Bump build number to … [skip ci]` do not re-trigger deploy
- **Skip CI on `[skip ci]` commits:** `ci.yml` skips validation on those commits
- **Allocate before build:** `scripts/allocate-ci-build-number.sh` pushes `ci/build-number` before archiving/uploading

**Troubleshooting duplicate Firebase build numbers**

If multiple Firebase releases show the same build number (e.g. three `1.000 (7)` entries), the usual cause is deploy runs that **uploaded an IPA but failed to persist** the next build number. Historically this was a blocked `git push` to `main`, or a 403 writing repository Actions variables with `GITHUB_TOKEN`.

Common failure modes:
1. Ruleset rejection of bump commits to `main` (fixed by persisting on unprotected `ci/build-number`)
2. Concurrent deploy runs before concurrency was added — both read the same base build number
3. Stale counter — set `BUILD_NUMBER` on `ci/build-number` ahead of the highest Firebase build and re-run deploy

Allocate-before-build ordering prevents new duplicates even when archive or Firebase upload fails later in the job.

### Future Enhancements

Planned or possible improvements to the CI/CD pipeline:

- ✅ **Build and archive:** Automated Firebase App Distribution _(completed in Step 2)_
- ✅ **Build number automation:** Auto-increment build numbers _(completed in Step 2)_
- ✅ **Release notes generation:** Extract PR info into release notes _(completed in Step 2)_
- ✅ **TestFlight distribution:** `testflight.yml` builds + uploads on `release/**` (upload needs the App Store Connect API secrets)
- **UI tests workflow:** Separate job for SpotUITests (longer runtime, separate from unit tests)
- **Static analysis:** SwiftLint, SwiftFormat, or similar tools
- **PR automation:** Danger for additional automated checks and comments
- **Coverage trending:** Track coverage changes over time
- **Performance tests:** Benchmark critical paths and track regressions
- **Deployment notifications:** Slack/Discord notifications on successful deploys

See `.github/workflows/README.md` for specific enhancement ideas.

### Re-enabling Xcode Cloud

If the team decides to re-enable Xcode Cloud in the future:

1. **Discuss strategy:** Decide if GitHub Actions should be replaced or run in parallel
2. **Remove marker file:** Delete `.xcode-cloud-disabled` from repository
3. **Configure workflows:** Set up workflows in App Store Connect
4. **Update documentation:** Revise this doc and workflow READMEs
5. **Update release process:** Modify [release-process.md](release-process.md) as needed
6. **Communicate to team:** Announce the CI/CD strategy change

## Related docs

- [.github/workflows/README.md](../../.github/workflows/README.md) — GitHub Actions workflows
- [firebase-distribution-setup.md](firebase-distribution-setup.md) — Firebase App Distribution setup guide
- [testing.md](testing.md) — Test organization and execution
- [release-process.md](release-process.md) — Pre-release and App Store process
- [troubleshooting.md](troubleshooting.md) — Common build and test failures
- [../diagrams/testing-release-flow.md](../diagrams/testing-release-flow.md) — Pipeline flow diagram

## Open questions / TODOs

- ~~Consider adding UI test workflow (SpotUITests) as separate job~~ (on roadmap)
- ~~Evaluate coverage reporting tools (Codecov, Coveralls, etc.)~~ (implemented with validate-coverage.sh)
- ~~Firebase build automation on merge to main~~ _(completed: deploy.yml)_
- ~~Build number automation and release notes generation~~ _(completed: deploy.yml)_
- Add SwiftLint or SwiftFormat for code style consistency (on roadmap)
- Add the App Store Connect API secrets (`APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8_BASE64`) so the TestFlight upload step in `testflight.yml` can complete

Branch protection is configured via GitHub repository rulesets (see [.github/rulesets/README.md](../../.github/rulesets/README.md)).
