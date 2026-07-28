# Product overview

## Purpose

Describe what Spot is, the core value proposition, and the main surfaces users interact with.

## Audience

Product, design, engineering, support, and reviewers.

## Current status

Reflects the shipped iOS app structure (tabs, flows) as implemented in `Spot/Views` and related services.

## Details

Spot is a **social place-discovery** iOS app. Users browse and share **Spots**—saved place recommendations from real people, organized around **vibe tags** (how a place feels), photos, and location.

### Core value

- Discover places through people you follow and broader discovery.
- Save, react to, and revisit recommendations quickly.
- Explore geographically on the **map** with a **spot drawer** (bottom card) for previews.

### What is a Spot?

A **Spot** is a user-created post: typically photos, a place, **vibe tags**, caption/details, and a creator. It is the primary unit of content in feeds and on the map.

### What are vibe tags?

**Vibe tags** are the app’s discovery labels—they describe atmosphere and use (for example “Hidden Gem”, “Scenic View”) rather than only rigid categories. Defaults are listed in `Spot/Utils/Constants.swift` under `Constants.VibeTags`.

### Major surfaces

| Surface | Role |
| --- | --- |
| **Home / feed** | Personalized scroll of Spots (`get_home_feed_v1` RPC on the backend). |
| **Map** | Viewport-based discovery, markers/clusters, **spot drawer** for selection. |
| **Post** | Multi-step flow to create and publish a Spot (media, place, vibes, publish). |
| **Search** | Users, places, vibes. |
| **Profile** | User’s Spots, social graph, settings, Pro entry points. |
| **Onboarding** | Active first-run coach (`SpotFirstRunOnboardingManager`); legacy tour state is migrated. |
| **Pro** | Subscription via StoreKit; gated features (see [pro-subscription.md](pro-subscription.md)). |
| **Support / legal** | Settings links to `spotapp.online/privacy`, `spotapp.online/terms`, and `support@spotapp.online`. |

### Product principles

1. **Trust and safety first** — authentication, RLS, and image moderation are non-negotiable (see engineering docs).
2. **Premium, minimal UI** — follow app theme in `Constants.Colors`.
3. **Vibe-centered discovery** — tags and feed/map discovery emphasize feeling and context.
4. **Social proof** — creators, follows, likes, bookmarks.
5. **Low friction** — fast browse and post where possible without sacrificing safety checks.

## Related docs

- [terminology.md](terminology.md)
- [user-flows.md](user-flows.md)
- [../engineering/architecture.md](../engineering/architecture.md)

## Open questions / TODOs

- Confirm App Store Connect metadata matches the code-verified legal URLs before each submission.
