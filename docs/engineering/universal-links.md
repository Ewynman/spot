# Universal Links and deep linking

## Purpose

Document Universal Links, custom URL schemes, entitlements, routing code, testing, and troubleshooting for Spot.

## Audience

Engineers, release owners, and anyone debugging share links.

## Current status

Verified against `Spot/Services/DeepLinkRouter.swift`, `Spot/ViewModels/DeepLinkState.swift`, `Spot/Utils/URLConfiguration.swift`, `Spot/Spot.entitlements`, and `Spot/Info.plist` (`SpotURLs`). Spot fetch uses **`SpotService`** / Supabase-backed services (not Firestore).

## Details

### What Universal Links are used for

- Open the app to a **specific Spot** from an `https` link on allowed hosts.
- Handle **subscription return** via custom scheme `spotapp://subscription/return` (StoreKit / web checkout return flow).

### Supported domains (production)

Associated Domains in `Spot/Spot.entitlements`:

- `applinks:spotapp.online`
- `applinks:www.spotapp.online`

**Allowed hosts for parsing:** `Info.plist` lists production hosts only; **Debug** builds also merge `URLConfiguration.debugOnlyUniversalLinkHosts` (localhost / tunnel—**not** in Release). Keep Associated Domains entitlements aligned with production (`applinks:spotapp.online`, etc.); dev tunnels are for device testing without adding new `applinks:` entries when using custom hosts only in code.

### Supported routes (code)

| Link type | Example | Expected behavior | Auth required? |
| --- | --- | --- | --- |
| Spot detail (Universal) | `https://spotapp.online/s/{spotId}` | Parse spot ID → fetch spot → show detail overlay or unavailable | Fetch uses session if present; unauthenticated users **store pending** link until auth |
| Spot detail (www) | `https://www.spotapp.online/s/{spotId}` | Same | Same |
| Spot (custom scheme) | `spotapp://spot/{spotId}` | Same as universal warm path | Same |
| Query variant | `spotapp://open?spotId={spotId}` | Same | Same |
| Subscription return | `spotapp://subscription/return` | If authenticated and server Pro state is active, shows `ProSuccessView` over the tab shell | Yes |
| Profile / username path | `/u/{username}` | **Not implemented** in `DeepLinkRouter` today | N/A |
| Invite / share beyond `/s/` | — | Not implemented by `DeepLinkRouter` | — |

**HTTP localhost** — `DeepLinkRouter` accepts `http://localhost` with `/s/:spotId` for local testing.

### Implementation components

1. **`DeepLinkRouter`** (`Spot/Services/DeepLinkRouter.swift`) — Parses URLs into `DeepLinkRoute` (`.spotDetail`, `.subscriptionReturn`, `.unknown`). Validates spot IDs: non-empty, max length 50, alphanumeric + `_` `-`.
2. **`DeepLinkState`** (`Spot/ViewModels/DeepLinkState.swift`) — `@MainActor` navigation state, pending deep link on cold start or when logged out, debounce for duplicate spot IDs, integrates **`SpotService.shared`** for `fetchSpotById`.
3. **`URLConfiguration`** — Reads `SpotURLs` from Info.plist for share base URL and allowed universal hosts; **`ShareSheet`** uses `shareURL(for:)` for `https://…/s/{id}` style links.

### Associated Domains setup

1. Enable capability in Xcode for the Spot target (matches `Spot.entitlements`).
2. Ensure Apple Team ID + bundle ID match the **`apple-app-site-association`** file on the web host.

### Apple App Site Association (AASA)

Host **without extension** at:

- `https://spotapp.online/.well-known/apple-app-site-association`
- `https://www.spotapp.online/.well-known/apple-app-site-association`

Must include paths for `/s/*` (and team/bundle mapping). **TODO: verify** live JSON on servers.

### Navigation behavior

**Cold start** — `handleInitialUserActivity` passes `NSUserActivity` webpage URL → may set `pendingDeepLink` before auth completes → `processPendingDeepLinks()` after session ready.

**Warm start / authenticated** — fetches spot; on success sets `spotDetailSpot` and `isNavigatingToSpot`; on failure shows **spot unavailable** UI.

**Unauthenticated** — pending spot link stored; after sign-in, pending route processed.

### Error handling

| Case | Behavior |
| --- | --- |
| Spot not found / blocked | `showSpotUnavailable` |
| Network error | Unavailable + logged |
| Invalid URL / path | `.unknown`, logged |

### Analytics

`DeepLinkRouter.logDeepLinkEvent` → `AnalyticsService.shared.trackDeepLink` with origin `universal_link` or `custom_scheme`.

### Testing

| Check | Steps |
| --- | --- |
| Universal cold start | Install build → tap `https://spotapp.online/s/<validSpotId>` from Messages/Safari |
| Universal warm start | App running → tap same |
| Custom scheme | Open `spotapp://spot/<validSpotId>` |
| Logged out | Confirm pending link resolves after login |
| Invalid ID | Malformed id rejected by router |

Simulator note: Universal Links can be finicky; **validate on device** before release.

### Troubleshooting

1. **Link opens Safari, not app** — AASA not reachable, wrong team/bundle, or entitlements not in installed build.
2. **App opens but wrong route** — Select logging profile 4 and check `DeepLinkRouter` logs; verify path is exactly `/s/{id}`.
3. **Custom scheme no-op** — Confirm `CFBundleURLTypes` includes `spotapp`.

### Release checklist (links)

- [ ] AASA live on both apex and `www`
- [ ] Entitlements domains match marketing URLs
- [ ] Smoke test one real Spot link on production build (device)
- [ ] Subscription return URL tested if checkout flow changed

## Related docs

- [configuration.md](configuration.md)
- [architecture.md](architecture.md)
- [networking-and-auth.md](networking-and-auth.md)
- [../diagrams/universal-links-flow.md](../diagrams/universal-links-flow.md)

## Open questions / TODOs

- No Settings deep-link test UI exists in the current source.
- Live AASA content remains a release-time external verification.
