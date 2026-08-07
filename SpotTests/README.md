# SpotTests

Unit tests for the Spot app (`SpotTests` scheme). Folder layout mirrors `Spot/` so tests live next to the production area they cover.

## Layout

| Folder | Mirrors | Examples |
| --- | --- | --- |
| `Models/` | `Spot/Models/` | `SpotModelTests`, `MapDiscoveryDrawerPolicyTests` |
| `ViewModels/` | `Spot/ViewModels/` | `FeedViewModelTests`, `MapViewModelStateTests` |
| `Services/` | `Spot/Services/` | `DeepLinkRouterTests`, `SubscriptionManagerRetryTests` |
| `Services/Auth/` | `Spot/Services/Auth/` | `StagingTestEmailVerificationTests` |
| `Services/Feed/` | `Spot/Services/Feed/` | `FeedRankerTests`, `FeedDiversityTests` |
| `Services/Moderation/` | `Spot/Services/Moderation/` | `ModerationServiceTests` |
| `Services/Spots/` | `Spot/Services/Spots/` | `SpotPublishDraftTests`, `VibeTagValidatorTests` |
| `Services/Supabase/` | `Spot/Services/Supabase/` | `SupabaseEnvironmentConfigurationTests` |
| `Utils/` | `Spot/Utils/` | `GeoHashTests`, `SpotLoggerTests` |
| `Managers/` | `Spot/Managers/` | `HomeTourManagerTests`, `LocationManagerDelegateTests` |
| `Views/` | `Spot/Views/` (logic extracted from views) | `WelcomeViewTests`, map policy/style tests under `Views/Components/Map/` |
| `Guards/` | Cross-cutting repo guards | `DataPlaneGuardTests` |
| `TestHelpers/` | Shared fixtures and mocks | `SpotTestHelpers`, `MockURLSession` |

`SpotTests.swift` at the target root is a lightweight smoke test that the module loads.

## Conventions

- Name files `{TypeUnderTest}Tests.swift`.
- Place new tests in the folder that matches the production file's location under `Spot/`.
- Keep shared mocks and fixtures in `TestHelpers/`; avoid duplicating helpers per suite.
- UI flows belong in `SpotUITests/`, not here.

## Running

```sh
xcodebuild -scheme SpotTests -destination "platform=iOS Simulator,name=iPhone 17 Pro" test
```

See [docs/engineering/testing.md](../docs/engineering/testing.md) and [docs/engineering/ci-cd.md](../docs/engineering/ci-cd.md) for coverage gates and CI behavior.
