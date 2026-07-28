# Map experience

## Purpose

Describe map discovery: pins, clustering, spot drawer, permissions, and Pro-related map behavior.

## Audience

Product, engineering, QA.

## Current status

Map UI lives under `Spot/Views/Home/MapView.swift`, `SharedSpotMap`, `MapControlsOverlay`, `MapSpotPreviewCard`. Drawer dismiss policy is covered by unit tests such as `SpotTests/MapDiscoveryDrawerPolicyTests.swift`.

## Details

### Purpose

The **map** lets users discover Spots near a viewport: markers (and density visualization), selection, and a **spot drawer** (bottom card) for quick preview.

### Pins and clusters

Markers use branded colors from `Constants.Colors` (map marker greens, cluster fill). Clustering / soft-density behavior is implemented in map components—see `SharedSpotMap` and related utilities.

### Spot drawer / bottom drawer

- Tapping a spot opens or updates the drawer.
- Tapping a **different** spot should **replace** the selection and drawer content for the new Spot.
- **Panning/zooming** away from the selected spot sufficiently should **dismiss** the drawer (policy encoded in map view model / coordinator—keep in sync with tests).

### Pro filtering

Pro-only map filters (if present) must remain **clearly gated** behind entitlement checks and covered by tests where possible.

### Location permission

Map and discovery may request location; prior prompt state is tracked in `UserDefaults` keys in `Constants.UserDefaultsKeys`.

- The map remains usable with a continental-US fallback before permission or when permission is denied.
- Granting permission from the native prompt or Settings triggers a location request while the map is open; switching tabs is not required.
- A persisted last-known-good coordinate may center the map immediately while Core Location obtains a fresh fix.
- The current-user marker uses the signed-in profile image when available and falls back to username initials or a person symbol.
- Refreshing permission or map state must not delete profile or Spot data; those refreshes only reload client-visible state.

### Empty / error / loading

Show appropriate placeholders or errors when viewport fetch fails or returns no spots (see map view model and logs under map-related log categories).

### Flow diagram

```mermaid
flowchart TD
  A[User opens map] --> B[Load visible Spots]
  B --> C[Render pins / clusters]
  C --> D{User taps pin?}
  D -->|Yes| E[Select Spot]
  E --> F[Open spot drawer]
  F --> G{User taps another pin?}
  G -->|Yes| H[Close existing drawer]
  H --> I[Open drawer for new Spot]
  F --> J{User pans or zooms away?}
  J -->|Yes| K[Close drawer]
  F --> L{User dismisses drawer?}
  L -->|Yes| K
```

## Related docs

- [../diagrams/map-spot-drawer-flow.md](../diagrams/map-spot-drawer-flow.md)
- [pro-subscription.md](pro-subscription.md)
- [../engineering/logging.md](../engineering/logging.md)

## Open questions / TODOs

- Exact numeric thresholds for “panned away” dismiss: see implementation next to `MapDrawerDismissReason` (or equivalent).
