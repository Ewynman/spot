# SpotUITests

UI tests for the Spot app (`SpotUITests` scheme). Folders mirror product
surfaces under `Spot/Views/` so smoke flows stay discoverable.

## Layout

| Folder | Covers | Production area |
| --- | --- | --- |
| `Launch/` | Cold launch smoke | `Spot/Views/Launch/`, root gate |
| `Authentication/` | Auth gate / welcome | `Spot/Views/Auth/` |
| `Onboarding/` | First-run / coach | `Spot/Views/Onboarding/` |
| `Posting/` | Post composer smoke | `Spot/Views/PostFlow/` |
| `Map/` | Map discovery / drawer | `Spot/Views/Home/MapView.swift` |
| `Profile/` | Profile, settings, private account | `Spot/Views/Profile/` |
| `Navigation/` | Tab shell | `Spot/Views/MainTabView.swift` |
| `TestSupport/` | Launch args, helpers | — |

`SpotUITestsLaunchTests.swift` remains at the target root (Xcode template
smoke). Prefer `accessibilityIdentifier` over localized strings.

## Conventions

- Keep flows short and deterministic; avoid live network where possible.
- Use `SpotUITestAppConfiguration` launch arguments for signed-in / Pro
  bootstrap in DEBUG.
- Unit-testable logic belongs in `SpotTests/`, not here.
- CI’s primary PR job runs `SpotTests`. Combined coverage with UI tests is
  collected by the optional UI coverage job (see `docs/engineering/ci-cd.md`).

## Running

```sh
xcodebuild -scheme SpotUITests -destination "platform=iOS Simulator,name=iPhone 17 Pro" test
```

Full plan (unit + UI) with coverage:

```sh
xcodebuild -scheme Spot -testPlan Spot \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -enableCodeCoverage YES test
```
