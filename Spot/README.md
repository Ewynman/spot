# Spot app sources

SwiftUI + ViewModel + service layout for the Spot iOS app. The `Spot` Xcode
target uses a synchronized root group, so new files under these folders are
picked up automatically.

## Layout

| Path | Role |
| --- | --- |
| `SpotApp.swift`, `AppDelegate.swift` | App entry and Firebase observability bootstrap |
| `Views/` | SwiftUI screens and components (`Auth`, `Home`, `PostFlow`, `Profile`, …) |
| `Views/Launch/` | Launch / splash UI |
| `ViewModels/` | `ObservableObject` state for screens |
| `Services/Auth/` | Auth session, credential stores, staging verification |
| `Services/Feed/` | Home feed RPC, ranking helpers, flags |
| `Services/Map/` | Map viewport loading |
| `Services/Moderation/` | Image moderation client, terms gate |
| `Services/Search/` | Search data sources |
| `Services/Spots/` | Publish coordinator, drafts, vibe usage |
| `Services/Supabase/` | Repositories and user sync |
| `Services/Subscriptions/` | StoreKit manager, paywall routing |
| `Services/Social/` | Follows, privacy cache, bookmarks collections |
| `Services/Profile/` | Profile service, avatars, user spots |
| `Services/Media/` | Image loading / processing |
| `Services/Content/` | Vibe tag service |
| `Services/Analytics/` | Analytics + perf metrics |
| `Services/Notifications/` | Local notification helpers |
| `Services/Core/` | Deep links, token service |
| `Managers/` | Cross-feature managers (location, permissions, tours) |
| `Models/` | Codable models |
| `Models/Logs/` | `SpotLog` event enums (excluded from coverage scope) |
| `Utils/` | Constants, validators, logging config |
| `Supabase/` | Client bootstrap and environment selection |

## Tests

Unit tests live under `SpotTests/` with the same folder mirror. See
[`SpotTests/README.md`](../SpotTests/README.md). UI flows live under
`SpotUITests/`.

Coverage scope (CI): all production Swift under `Spot/` including Views;
excludes `Models/Logs/`. See `scripts/coverage_scope.py`.
