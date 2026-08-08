# SpotTests

Unit tests for the Spot app (`SpotTests` scheme). Folder layout mirrors `Spot/`
so tests live next to the production area they cover.

## Layout

| Folder | Mirrors | Examples |
| --- | --- | --- |
| `Models/` | `Spot/Models/` | `SpotModelTests`, `MapDiscoveryDrawerPolicyTests` |
| `ViewModels/` | `Spot/ViewModels/` | `FeedViewModelTests`, `MapViewModelStateTests` |
| `Services/Auth/` | `Spot/Services/Auth/` | `StagingTestEmailVerificationTests` |
| `Services/Feed/` | `Spot/Services/Feed/` | `FeedRankerTests`, `FeedDiversityTests` |
| `Services/Moderation/` | `Spot/Services/Moderation/` | `ModerationServiceTests` |
| `Services/Spots/` | `Spot/Services/Spots/` | `SpotPublishDraftTests` |
| `Services/Supabase/` | `Spot/Services/Supabase/` | `SupabaseEnvironmentConfigurationTests` |
| `Services/Subscriptions/` | `Spot/Services/Subscriptions/` | `SubscriptionManagerRetryTests` |
| `Services/Social/` | `Spot/Services/Social/` | `AuthorPrivacyCacheTests` |
| `Services/Core/` | `Spot/Services/Core/` | `DeepLinkRouterTests` |
| `Utils/` | `Spot/Utils/` | `GeoHashTests`, `SpotLoggerTests` |
| `Managers/` | `Spot/Managers/` | `HomeTourManagerTests` |
| `Views/` | `Spot/Views/` | Auth/onboarding/map logic tests |
| `Guards/` | Cross-cutting repo guards | `DataPlaneGuardTests` |
| `TestHelpers/` | Shared fixtures and mocks | `SpotTestHelpers`, `MockURLSession` |

`SpotTests.swift` at the target root is a lightweight smoke test that the module loads.

## Conventions

- Name files `{TypeUnderTest}Tests.swift`.
- Place new tests in the folder that matches the production file under `Spot/`.
- Keep shared mocks and fixtures in `TestHelpers/`.
- UI flows belong in `SpotUITests/`, not here.
- `Spot/Models/Logs/` is outside coverage scope; do not add tests solely for log enums.

## Running

```sh
xcodebuild -scheme SpotTests -destination "platform=iOS Simulator,name=iPhone 17 Pro" test
```

See [docs/engineering/testing.md](../docs/engineering/testing.md) and
[docs/engineering/ci-cd.md](../docs/engineering/ci-cd.md).
