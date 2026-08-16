# Onboarding

## Purpose

Explain first-run onboarding: what it teaches, where it starts, and how it differs from other tours.

## Audience

Product, UX, engineering, support.

## Current status

Verified against `SpotFirstRunOnboardingManager` and its production host in `BottomTabNavigationView` on 2026-08-16.

## Details

### Why onboarding exists

Onboarding orients new users to **what a Spot is**, **vibe tags**, **likes/bookmarks/follows**, **the Home card map flip**, **map discovery**, and **posting**—without blocking returning users.

### Entry points and behavior

`SpotFirstRunOnboardingManager` is the active production coach. `BottomTabNavigationView` evaluates it after authentication for a first-session candidate (no liked or bookmarked Spots). Steps are: welcome, Spot card, place-first details, vibe, like, bookmark, map flip, creator, map tab, user location, markers, marker preview, and finale. Completion or skip is tracked per user under `spotFirstRunOnboarding.*` keys in `UserDefaults`.

`HomeTourManager` remains in source and unit tests for migration compatibility, but `HomeTourHost` is not mounted in production navigation. The active manager migrates legacy `hasSeenHomeTour.*` state so returning users are not shown duplicate coaching.

### What onboarding teaches

- **Spot** as the core content unit (place-first Home card).
- **Vibe tags** as discovery language.
- **Like / bookmark** for taste and saving.
- **Map flip** on the Home card — tap the green marker to see geography, then **Open in Map** for the full Map tab.
- **Follow** creators via the shared-by row.
- **Map tab**, **user location**, **markers**, **marker preview** → bridge into map discovery.

At the user-location step, onboarding can present the location permission sheet. Completing or skipping the coach can present the notification pre-prompt after a 600 ms delay when authorization is still undetermined. Neither permission blocks authentication or access to the tab shell.

### Pro tour

The codebase includes flows for **Pro** (paywall, StoreKit). **Do not change the existing Pro purchase / tour UX** unless a task explicitly asks for it—per team rule preserved in `.cursor/rules/project.mdc`.

### Distinction: “normal” onboarding vs Pro

- **Normal onboarding** — `SpotFirstRunOnboardingManager` for core app literacy.
- **Pro** — Subscription paywall and entitlements; separate from first-run coach content.

## Related docs

- [user-flows.md](user-flows.md)
- [map-experience.md](map-experience.md)
- [../engineering/architecture.md](../engineering/architecture.md)
- [../engineering/notifications.md](../engineering/notifications.md)

## Open questions / TODOs

- None.
