# Testing

## Purpose

Testing philosophy, schemes, how to run tests, and what to cover.

## Audience

Engineers and CI owners.

## Current status

Matches `.cursor/rules/project.mdc` and Xcode schemes **Spot**, **SpotTests**, **SpotUITests**.

## Details

### Philosophy

- **Unit tests** for deterministic logic (validators, ranking helpers, deep link parsing, map policy, view model rules, extracted view helpers) with mocks—no live network or Apple sign-in prompts.
- **UI tests** for stable smoke flows using `accessibilityIdentifier` where possible.
- Prefer **extract-and-test** for SwiftUI: move pure logic into `Spot/Utils/` or ViewModels, then cover it in `SpotTests/`.

### Schemes

| Scheme | Runs |
| --- | --- |
| **Spot** | App; test action may run `Spot.xctestplan` (unit + UI). |
| **SpotTests** | `SpotTests` only — fast. |
| **SpotUITests** | `SpotUITests` + `SpotUITests.xctestplan`. |

### Coverage ownership

| Domain | Primary production folders | Preferred tests |
| --- | --- | --- |
| Auth / onboarding | `Services/Auth/`, `Views/Auth/`, `Views/Onboarding/` | Unit + `SpotUITests/Authentication` |
| Posting | `ViewModels/PostFlowViewModel`, `Views/PostFlow/`, `Services/Spots/` | Unit (limits, drafts, moderation parse) + posting UI smoke |
| Map / feed | `Views/Home/`, `Views/Components/Map/`, `Services/Feed/` | Map policy unit tests + map UI smoke |
| Profile / social | `Views/Profile/`, `Services/Profile/`, `Services/Social/` | Empty-state / privacy unit + profile UI |
| Pro / paywall | `Services/Subscriptions/`, `Views/Components/PaywallView` | Subscription static/error unit + gated-entry UI |
| Repo guards | `Spot/` tree | `SpotTests/Guards/DataPlaneGuardTests` |

Folder mirrors: [`Spot/README.md`](../../Spot/README.md), [`SpotTests/README.md`](../../SpotTests/README.md), [`SpotUITests/README.md`](../../SpotUITests/README.md).

### Coverage scope (CI)

Defined by [`scripts/coverage_scope.py`](../../scripts/coverage_scope.py):

- **Informational / whole-file metric:** all `Spot/**` production Swift, including Views
- **Changed-line PR gate:** same, but **excludes `Spot/Views/**`** (SwiftUI `body` is not run by SpotTests). Extract logic into Utils/ViewModels/Services for the gate; cover View bodies via SpotUITests / the informational combined-coverage job.
- **Exclude always:** `Spot/Models/Logs/`, test targets, packages
- **Renames:** pure `R100` moves are omitted from the gate (no executable lines changed)

PR gate: **80% of changed executable lines** per enforced file (10-line floor). Xcode’s whole-target % includes packages and will look much lower than CI’s production-scope metric.

### What should be tested (non-exhaustive)

- Auth gating and session edge cases (unit where mockable).
- Posting flow state machine and moderation client behavior.
- Draft behavior when testable without device-only APIs.
- Supabase repository behavior behind protocols/mocks; no live Supabase calls in unit tests.
- **Map drawer** selection / dismiss policy (`MapDiscoveryDrawerPolicyTests`, panel height tests, etc.).
- **Data plane guard** — `DataPlaneGuardTests` ensures no legacy Firebase Firestore/Storage upload code under `Spot/`.
- Onboarding managers (`HomeTourManagerTests`, etc.).
- **Pro** gating helpers (`ProEntitlementChecker`, subscription manager error paths).
- **Universal Links** parsing in `DeepLinkRouterTests`.
- **Private accounts** — `AuthorPrivacyCacheTests`, `FollowRequestsServiceTests`, and `PrivateAccountIntegrationTests`. See [../testing/private-account-tests.md](../testing/private-account-tests.md).

### Commands

```sh
SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
BEAUTIFY=$(command -v xcbeautify >/dev/null && echo "xcbeautify" || echo "cat")

xcodebuild -scheme SpotTests -destination "id=$SIM_ID" test | $BEAUTIFY
xcodebuild -scheme SpotUITests -destination "id=$SIM_ID" test | $BEAUTIFY
```

### Adding tests

- Place Swift Testing tests in **`SpotTests/`**, in the subfolder that mirrors the production file under `Spot/` (see `SpotTests/README.md`).
- Place XCTest UI tests in **`SpotUITests/`** under the matching domain folder (see `SpotUITests/README.md`).
- Do not cross-contaminate targets (per project rules).

### SwiftUI previews

Add previews for new or heavily changed UI when practical to speed design review.

## Related docs

- [local-setup.md](local-setup.md)
- [ci-cd.md](ci-cd.md)
- [../diagrams/testing-release-flow.md](../diagrams/testing-release-flow.md)
- [../testing/private-account-tests.md](../testing/private-account-tests.md)

### Release smoke priorities

1. Cold launch signed out and with a restored session.
2. Email signup, OTP recovery, login, and logout.
3. Staging DEBUG / internal builds: allowlisted email + internal `UT####` code on Confirm Email (real emailed OTP still works).
4. First-run coach complete and skip paths.
5. Home feed load, refresh, and load more.
6. Map pin selection, replacement, and pan-away drawer dismissal.
7. Search user/location/vibe result flows.
8. Private profile request, accept/deny, and block visibility.
9. Draft save/resume and one moderated Spot publish.
10. Pro purchase/restore and gated-feature entry points.
11. Cold/warm Universal Link with available and unavailable Spots.

CI’s PR gate runs `SpotTests`. An informational combined `Spot.xctestplan` coverage job also runs (does not gate merges).
