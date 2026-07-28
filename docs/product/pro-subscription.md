# Pro subscription

## Purpose

Document Spot Pro: paywall entry points, StoreKit product ID, restore behavior, and gated features at a high level.

## Audience

Product, engineering, App Store review.

## Current status

StoreKit integration: `Spot/Services/SubscriptionManager.swift`, product IDs in `Spot/Utils/SpotProProducts.swift`. Subscription return deep link: `spotapp://subscription/return` handled in `DeepLinkRouter`.

## Details

### What Pro is

**Pro** is the paid subscription tier unlocking premium creation, saving, map, and Search capabilities.

### Product ID (code)

| ID | Kind | Source |
| --- | --- | --- |
| `spotPro` | Yearly (primary product loaded first) | `SpotProProducts.yearly` |

**Pricing** is localized via StoreKit `Product.displayPrice`—not hardcoded. **App Store Connect** price tiers: **TODO: verify in App Store Connect**.

### Paywall entry points

Profile and Settings expose “Go Pro.” Feature limits route through `PaywallRouter.show()`, which posts `.showPaywall`; `RootView` owns the paywall sheet. Successful purchase can post `.showPostPurchaseProOnboarding`.

### Restore purchases

`SubscriptionManager` exposes restore flows (see `SubscriptionManager` for `isRestoring` and restore completion logs). User-facing copy lives in paywall views.

### Pro-gated features

| Feature | Free | Pro |
| --- | --- | --- |
| Photos per Spot | 1 | Up to 5 |
| Vibe tags per Spot | 1 | Up to 5, including composer custom-vibe support |
| Bookmarks | 50 | Unlimited with collections UI |
| Map filters | Hidden | Vibe, saved, liked, following |
| Search filters | Basic grids | Location plus selected vibe tags |
| Map user marker | Standard green ring | Gold ring |

Entitlement state combines StoreKit transaction updates with server `is_pro` / `pro_until` fields. Publish limits are enforced again by the Supabase RPC.

### Subscription testing

- Use **Sandbox** Apple IDs and Xcode StoreKit testing configuration.
- Local StoreKit testing uses `Spot/StoreKit/SpotDev.storekit`, which contains the yearly `spotPro` product.

### Localized price

Built from `SubscriptionPriceLineFormatter` + `Product` subscription period.

## Related docs

- [../diagrams/subscription-flow.md](../diagrams/subscription-flow.md)
- [../engineering/release-process.md](../engineering/release-process.md)
- [../operations/app-store-review-notes.md](../operations/app-store-review-notes.md)

## Open questions / TODOs

- Confirm App Store Connect pricing, product metadata, and review screenshots outside the repository before release.
- The map Following filter is visible to Pro users but does not yet receive followed-user IDs.
