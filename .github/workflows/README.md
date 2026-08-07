# GitHub Actions CI/CD

This directory contains GitHub Actions workflows for the Spot iOS app.

## Workflows

### `ci.yml` - Continuous Integration

**Triggers:**
- Pull requests to `main` and `release/**`
- Pushes to `main` (except `[skip ci]` commits)
- Merge queue groups on `main` (`merge_group`, when merge queue is enabled)

**What it does:**
- Runs comprehensive PR validation including:
  - **API Breaking Change Detection**: Scans for changes to public Swift APIs
  - **Documentation Validation**: Checks if documentation needs updates
  - **Unit Tests**: Runs the full `SpotTests` suite with one serial test worker
  - **Code Coverage Enforcement**: Validates 80% minimum coverage of the lines changed in non-view files
- Uses macOS 15 runners and reports the selected Xcode version at runtime
- Boots an iPhone simulator and executes tests
- Enables code coverage collection
- Posts validation results as PR comment
- Uploads test results and coverage reports as artifacts

**Validation Scripts:**

The workflow uses three validation scripts in `scripts/`:

1. **`validate-api-changes.sh`**
   - Detects potential breaking changes to public APIs
   - Checks for removed/modified public functions, classes, structs, enums
   - Warns if breaking changes detected (doesn't fail PR, but alerts reviewers)

2. **`validate-documentation.sh`**
   - Validates documentation updates for code changes
   - Checks specific patterns (e.g., service changes → architecture docs)
   - Provides suggestions for which docs may need updates

3. **`validate-coverage.sh`**
   - Enforces 80% minimum coverage of the lines changed in non-view production files
   - Excludes `Spot/Views/`, which belongs to the separate UI-test coverage boundary
   - Uses `xcrun xccov` to extract coverage from `.xcresult` bundles
   - Fails PR if coverage threshold not met
   - Shows detailed per-file coverage breakdown

The PR comment also includes an informational unit-test scope percentage from
`scripts/summarize-xccov.py`. It includes non-view `Spot.app` production files
only; package dependencies, test targets, and SwiftUI views are excluded. This
avoids presenting the root `xccov` aggregate—which includes linked packages—as
if it represented the app's test coverage.

**Test output:**
- Test results are formatted with `xcbeautify` for readable output
- Test results (`.xcresult` bundles) are uploaded as artifacts for 7 days
- Code coverage reports are uploaded as artifacts for 7 days
- Validation results posted as PR comment with pass/fail status

---

### `deploy.yml` - Firebase App Distribution Deployment (Test ENV)

**Triggers:**
- Pushes to `main` that include an app, test, build, script, backend, or workflow change
- Manual workflow dispatch

Documentation and repository-maintenance-only pushes are ignored, so they do not consume a build number or publish an unchanged IPA. A mixed change still deploys when it includes any non-ignored file. Manual dispatch remains available for an intentional rebuild.

This trigger does not depend on the separate CI workflow. Repository branch protection and merge policy are responsible for preventing unvalidated changes from reaching `main`.

**What it does:**
- Automatically increments build number in `CURRENT_PROJECT_VERSION` (build number `+1` only)
- Pushes build number update to `main` before building (prevents duplicate Firebase build numbers)
- Resolves the merged PR associated with the deployed commit
- Converts the PR's `Changes` section to concise plain-text Firebase release notes (Markdown and checklist boilerplate are removed)
- Injects Firebase configuration (`GoogleService-Info.plist`) from secrets
- Installs Apple signing assets into a temporary CI keychain (never the login keychain)
- Archives unsigned, then exports a **signed Ad Hoc IPA** for distribution
- Uploads to Firebase App Distribution for the `testers` group
- Creates deployment summary in GitHub Actions

**Signing assets (Firebase / Ad Hoc lane):**
- Certificate: `FIREBASE_DEV_CERT` (base64-encoded **.p12**; despite the name this is the Apple **Distribution** cert used for CI)
- Provisioning profile: `FIREBASE_PROVISIONING_PROFILE` (base64-encoded **.mobileprovision**, Ad Hoc)
- Export options template: `ExportOptions-Firebase.plist` (`method = ad-hoc`)

**Required GitHub Secrets:**
- `GOOGLE_SERVICE_INFO_PLIST_BASE64` - Firebase GoogleService-Info.plist (base64 encoded)
- `FIREBASE_APP_ID` - Firebase iOS App ID
- `FIREBASE_SERVICE_ACCOUNT_JSON` - Firebase service account credentials (raw JSON)
- `FIREBASE_DEV_CERT` - Apple Distribution certificate (.p12, base64 encoded)
- `APPLE_CERTIFICATE_PASSWORD` - Password used when exporting the .p12
- `FIREBASE_PROVISIONING_PROFILE` - Ad Hoc provisioning profile (.mobileprovision, base64 encoded)
- `KEYCHAIN_PASSWORD` - Temporary CI keychain password (any secure random string)

See [docs/engineering/firebase-distribution-setup.md](../../docs/engineering/firebase-distribution-setup.md) for detailed setup instructions.

**Build versioning:**
- Marketing version: `1.000` (manual updates)
- Build number: Auto-incremented on every deploy (e.g., 9 → 10)

**Important notes:**
- GoogleService-Info.plist is required for Firebase initialization - without it, the app will crash on launch
- Build number is committed and pushed before archiving to prevent duplicate Firebase builds
- Concurrent deploys are serialized via the `deploy-firebase-main` concurrency group
- Bump commits (`Bump build number to ... [skip ci]`) do not re-trigger CI or deploy workflows
- Firebase App Distribution treats release notes as plain text; `scripts/format-firebase-release-notes.py` keeps the tester notes and rendered Actions summary readable
- Documentation/Markdown, agent configuration, ignore-file, and license-only changes do not trigger a Firebase build

---

### `testflight.yml` - App Store Connect / TestFlight Deployment

**Triggers:**
- Pushes to `release/**` branches
- Manual workflow dispatch (from a `release/**` branch)

**What it does:**
- Derives the marketing version from the branch name (e.g. `release/1.1.0` → `MARKETING_VERSION=1.1.0`)
- Increments `CURRENT_PROJECT_VERSION` with `scripts/increment-build-number.sh` (the marketing version itself is not auto-bumped)
- Injects Firebase configuration (`GoogleService-Info.plist`) from secrets
- Installs Apple signing assets into a temporary CI keychain
- Archives unsigned, then exports a **signed App Store IPA**
- Uploads the IPA artifact, then uploads to App Store Connect / TestFlight via `xcrun altool`
- Does **not** submit to App Store Review

**Versioning example:** if the committed project build is 35, a `release/1.1.0` run sets marketing version `1.1.0` and increments the project build to 36.

**Signing assets (TestFlight / App Store lane):**
- Certificate: `TESTFLIGHT_APPLE_CERT` (base64-encoded **.p12**, Apple Distribution)
- Provisioning profile: `TESTFLIGHT_APPLE_PROFILE` (base64-encoded **.mobileprovision**, App Store Connect). *(The PRD calls this `TESTFLIGHT_PROVISIONING_PROFILE`, but the secret configured in the repo is `TESTFLIGHT_APPLE_PROFILE`; we reference the existing secret rather than renaming it.)*
- Export options template: `ExportOptions-TestFlight.plist` (`method = app-store`)

**Required GitHub Secrets:**
- `GOOGLE_SERVICE_INFO_PLIST_BASE64`
- `TESTFLIGHT_APPLE_CERT`
- `APPLE_CERTIFICATE_PASSWORD`
- `TESTFLIGHT_APPLE_PROFILE`
- `KEYCHAIN_PASSWORD`

**⚠️ App Store Connect API secrets required for upload (NOT yet configured):**

The build/archive/export steps run without them, but the **TestFlight upload step fails with a clear message** until these are added:

- `APP_STORE_CONNECT_API_KEY_ID` - the App Store Connect API Key ID
- `APP_STORE_CONNECT_API_ISSUER_ID` - the Issuer ID (UUID)
- `APP_STORE_CONNECT_API_KEY_P8_BASE64` - base64 of the `AuthKey_XXX.p8` file

Create the key at App Store Connect → **Users and Access → Integrations → App Store Connect API**.

---

## Requirements

### CI Requirements

The CI workflow expects:
- A valid `SpotTests` scheme in the Xcode project
- Tests that can run on iOS Simulator
- No manual provisioning profiles required for unit tests
- `jq` installed (for JSON parsing in validation scripts)
- Validation scripts in `scripts/` directory:
  - `validate-api-changes.sh`
  - `validate-documentation.sh`
  - `validate-coverage.sh`

### Deploy Requirements

The Firebase deploy workflow (`deploy.yml`) requires:
- The Firebase-lane secrets configured (see above)
- A valid Apple Distribution certificate (`FIREBASE_DEV_CERT`) and **Ad Hoc** provisioning profile (`FIREBASE_PROVISIONING_PROFILE`)
- Firebase project with App Distribution enabled
- `testers` group created in Firebase App Distribution
- Valid `GoogleService-Info.plist` from Firebase Console

The TestFlight workflow (`testflight.yml`) requires:
- The TestFlight-lane secrets configured (see above)
- A valid Apple Distribution certificate (`TESTFLIGHT_APPLE_CERT`) and **App Store Connect** provisioning profile (`TESTFLIGHT_APPLE_PROFILE`)
- App Store Connect API secrets (`APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8_BASE64`) for the upload step
- A `release/<version>` branch (e.g. `release/1.1.0`) so the version can be derived

---

## Local Testing

To run the same tests locally that CI runs:

```bash
# Get first available iPhone simulator
SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')

# Run unit tests
xcodebuild \
  -scheme SpotTests \
  -destination "id=$SIM_ID" \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -enableCodeCoverage YES \
  test | xcbeautify
```

---

## Troubleshooting

### "App crashes immediately on launch" after Firebase App Distribution download

**Cause**: Missing `GOOGLE_SERVICE_INFO_PLIST_BASE64` secret in GitHub repository settings.

**Solution**: 
1. Download `GoogleService-Info.plist` from Firebase Console
2. Convert to base64: `base64 -i GoogleService-Info.plist | pbcopy`
3. Add as `GOOGLE_SERVICE_INFO_PLIST_BASE64` secret in GitHub repository settings
4. Re-run the deployment workflow

See [docs/engineering/firebase-distribution-setup.md](../../docs/engineering/firebase-distribution-setup.md) for full setup guide.

### Duplicate Firebase build numbers

**Cause**: Deploy workflow uploaded an IPA but failed to push the incremented build number back to `main`.

**Solution**: The workflow now commits and pushes build numbers *before* archiving, preventing this issue. If you encounter duplicate builds from old deploys, they can be ignored - new deploys will use the correct incremented number.

---

## Future Enhancements

Consider adding:
- ✅ Firebase App Distribution automation (completed)
- ✅ Build number automation (completed)
- ✅ Release notes generation (completed)
- ✅ TestFlight upload on `release/**` branches (`testflight.yml`; upload needs the App Store Connect API secrets)
- UI test workflow (separate from unit tests due to longer runtime)
- SwiftLint or other static analysis tools
- Danger for additional automated PR checks
- Coverage trending over time
- Deployment notifications (Slack/Discord)
