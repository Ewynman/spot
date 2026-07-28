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
| `Supabase` | `url` and `anonKey` for `SupabaseClient` initialization. |
| Usage descriptions | Notifications, photos, camera, location as required by Apple. |

### Entitlements (`Spot/Spot.entitlements`)

- **Sign in with Apple** — `com.apple.developer.applesignin`
- **Associated Domains** — `applinks:spotapp.online`, `applinks:www.spotapp.online`

### Universal Links vs DEBUG

**Release / App Store:** `Info.plist` → `SpotURLs` → `universalLinkDomains` lists **production** hosts only (`spotapp.online`, `www.spotapp.online`).

**Debug:** `URLConfiguration` appends `debugOnlyUniversalLinkHosts` in `URLConfiguration.swift` (e.g. `localhost`, a tunnel host) so local and tunnel testing work without shipping those in Release. **`DeepLinkRouter`** allows `https` only when `URLConfiguration.isAllowedUniversalLinkHost` returns true; `http://localhost` is also accepted in the router for local testing.

### Logging defaults

`Config/LoggingDefaults.plist` (bundled) seeds `LoggingConfig` / `UserDefaults` toggles—see [logging.md](logging.md).

### Settings bundle authentication reset

`Spot/Settings.bundle/Root.plist` exposes **Clear Keychain on Next Launch** under Authentication Testing. It is a one-shot testing control:

1. Turn the switch on in the iOS Settings app.
2. Fully quit Spot.
3. Reopen Spot.

Before constructing the Supabase client, Spot deletes generic-password Keychain items in its own application access group and immediately resets the switch to off. This clears the persisted Supabase session plus Spot’s account-hint, verification-recovery, and legacy token entries. It does not delete passwords managed by Apple Password AutoFill or other apps.

## Related docs

- [universal-links.md](universal-links.md)
- [environment-variables.md](environment-variables.md)

## Open questions / TODOs

- Document any xcconfig files if introduced for multi-environment builds: TODO: verify.
