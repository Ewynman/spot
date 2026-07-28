# Local setup

## Purpose

How to open the project, build, and run tests on simulator or device.

## Audience

New developers and CI maintainers.

## Current status

Verified against `Spot.xcodeproj` build settings (deployment target and Swift version vary by target—see tables below).

## Details

### Prerequisites

| Requirement | Notes |
| --- | --- |
| **macOS + Xcode** | Use an Xcode version that supports the installed iOS simulator runtime and iOS 17 deployment target. CI uses `macos-15`; distribution workflows select or require Xcode 26. |
| **iOS deployment target** | App and test targets use iOS 17.0; project-level settings also contain 18.5 values, so inspect the active target when changing deployment support. |
| **Swift** | **5.0** in project settings. |
| **Supabase** | Local DEBUG selects staging in `Spot/Supabase/Supabase.swift`. Release workflows inject `Info.plist` values. |
| **Firebase** | A valid gitignored `GoogleService-Info.plist` is needed for normal Firebase initialization; CI injects it from secrets. |
| **Apple Developer** | For device runs, push, Associated Domains, and Sign in with Apple as enabled for the bundle ID. |

### Clone and open

```sh
git clone <repository-url>
cd <cloned-repository-directory>
open Spot.xcodeproj
```

### Build (example)

From the repo root, with a simulator UDID:

```sh
SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
BEAUTIFY=$(command -v xcbeautify >/dev/null && echo "xcbeautify" || echo "cat")
xcodebuild -scheme Spot -destination "id=$SIM_ID" build | $BEAUTIFY
```

### Schemes

| Scheme | Use |
| --- | --- |
| **Spot** | Run and archive the app. Test action can run **both** unit and UI tests via `Spot.xctestplan`. |
| **SpotTests** | **Unit tests only** — fast pre-commit. |
| **SpotUITests** | **UI tests only** via `SpotUITests.xctestplan`. |

### Simulator vs device

- Simulator: good for most UI and unit tests; **Universal Links** behavior is most reliable on **physical devices** with real Associated Domains + AASA.
- Device: required for full deep-link / AASA validation and some permissions.

### Common local issues

See [troubleshooting.md](troubleshooting.md).

## Related docs

- [configuration.md](configuration.md)
- [testing.md](testing.md)

## Open questions / TODOs

- Pin one canonical local Xcode version when the team standardizes it; workflow requirements remain authoritative for distribution.
