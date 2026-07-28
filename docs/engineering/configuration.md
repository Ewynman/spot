# Configuration

## Purpose

Where non-code configuration lives: Info.plist, entitlements, URL schemes, Associated Domains.

## Audience

Engineers setting up local builds and release signing.

## Current status

Verified file paths: `Spot/Info.plist`, `Spot/Spot.entitlements`.

## Details

### Info.plist

| Key area | Purpose |
| --- | --- |
| `CFBundleURLTypes` | Custom URL scheme **`spotapp`** for deep links. |
| `SpotURLs` | `shareURLBase`, `universalLinkDomains`, `customScheme` read by `URLConfiguration`. |
| `Supabase` | Release-workflow-injected `url` and `anonKey`; DEBUG uses `SupabaseEnvironment` in `Supabase.swift`. |
| Generated usage descriptions | Camera, photo-library, and location strings are set through Xcode `INFOPLIST_KEY_*` build settings in `project.pbxproj`. |

Notification authorization uses UserNotifications and does not have a plist usage-description key. Notification categories and the delegate are registered by `AppDelegate`.

### Entitlements (`Spot/Spot.entitlements`)

- **Sign in with Apple** — `com.apple.developer.applesignin`
- **Associated Domains** — `applinks:spotapp.online`, `applinks:www.spotapp.online`

### Universal Links vs DEBUG

**Release / App Store:** `Info.plist` → `SpotURLs` → `universalLinkDomains` lists **production** hosts only (`spotapp.online`, `www.spotapp.online`).

**Debug:** `URLConfiguration` appends `debugOnlyUniversalLinkHosts` in `URLConfiguration.swift` (e.g. `localhost`, a tunnel host) so local and tunnel testing work without shipping those in Release. **`DeepLinkRouter`** allows `https` only when `URLConfiguration.isAllowedUniversalLinkHost` returns true; `http://localhost` is also accepted in the router for local testing.

### Logging defaults

`Config/LoggingDefaults.plist` (bundled) seeds `LoggingConfig` / `UserDefaults` toggles—see [logging.md](logging.md).

## Related docs

- [universal-links.md](universal-links.md)
- [environment-variables.md](environment-variables.md)

## Open questions / TODOs

- Document any xcconfig files if introduced for multi-environment builds: TODO: verify.
