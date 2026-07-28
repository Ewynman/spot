# Diagram: Map spot drawer

## Purpose

State-style view of map selection and drawer.

## Audience

Engineering, QA.

## Current status

Verified against map selection and drawer-policy tests.

## Details

```mermaid
stateDiagram-v2
  [*] --> MapIdle
  MapIdle --> SpotSelected: user taps pin
  SpotSelected --> DrawerOpen: open drawer
  DrawerOpen --> DrawerOpen: different pin replaces selected Spot
  DrawerOpen --> MapIdle: user dismisses drawer
  DrawerOpen --> MapIdle: user pans or zooms away
```

## Related docs

- [../product/map-experience.md](../product/map-experience.md)

The drawer hosts `MapSpotPreviewCard` and the shared `SpotCard`; there is no separate `SpotDetailView` transition.

## Open questions / TODOs

- None.
