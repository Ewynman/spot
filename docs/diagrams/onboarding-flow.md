# Diagram: Onboarding

## Purpose

Visualize first-run onboarding relative to the main shell.

## Audience

Product and engineering.

## Current status

Verified against `SpotFirstRunOnboardingManager` wiring in `BottomTabNavigationView`. `HomeTourManager` is legacy and unmounted.

## Details

```mermaid
flowchart TD
  A[Verified user enters tab shell] --> B{First-session candidate and not completed?}
  B -->|No| C[Normal tabs]
  B -->|Yes| D[SpotFirstRunOnboarding overlay]
  D --> E[Spot card, social, and map coach steps]
  E --> F{Complete or skip}
  F --> G{Notification permission undetermined?}
  G -->|Yes| H[Notification pre-prompt after 600 ms]
  G -->|No| C
  H --> C
  E --> I[User-location step]
  I --> J[Optional location permission sheet]
  J --> E
```

## Related docs

- [../product/onboarding.md](../product/onboarding.md)

## Open questions / TODOs

- None.
