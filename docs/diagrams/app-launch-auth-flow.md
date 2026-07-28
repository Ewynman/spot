# Diagram: App launch and authentication

## Purpose

Visualize cold start through session validation and main shell.

## Audience

Engineers, reviewers.

## Current status

Verified against `AppDelegate`, `SpotApp`, `AuthViewModel`, and `RootView` on 2026-07-28.

## Details

```mermaid
flowchart TD
  A[AppDelegate launch setup] --> B[SpotApp branded splash]
  B --> C[RootView]
  C --> D{AuthViewModel loading?}
  D -->|Yes| B
  D -->|No| E{Pending verification recovery?}
  E -->|Yes| F[ConfirmEmailView]
  E -->|No| G{Session exists?}
  G -->|No| H{Saved account hint?}
  H -->|Yes| I[WelcomeBackView]
  H -->|No| J[WelcomeView]
  G -->|Yes| K{Session expired?}
  K -->|Yes| L[Refresh session]
  L --> M{Refresh succeeds?}
  M -->|No| H
  M -->|Yes| N{Email verified?}
  K -->|No| N
  N -->|No| F
  N -->|Yes| O{Apple username setup needed?}
  O -->|Yes| P[PostAuthSetupFlowView]
  O -->|No| Q[MainTabView]
  P --> Q
  Q --> R[Contextual first-run coach and permissions]
```

Authentication entry and new-device paths:

```mermaid
flowchart LR
  A[Option A editorial welcome] --> B[Create account]
  B --> C[Email + username + password]
  C --> D[Six-digit signup OTP when required]
  D --> E[Authenticated session]
  A --> F[Email login]
  A --> G[Sign in with Apple + nonce]
  H[New device] --> G
  H --> I[iCloud Password AutoFill]
  H -. not implemented .-> J[Passkey]
```

## Related docs

- [../engineering/networking-and-auth.md](../engineering/networking-and-auth.md)
- [../product/user-flows.md](../product/user-flows.md)

## Open questions / TODOs

- None.
