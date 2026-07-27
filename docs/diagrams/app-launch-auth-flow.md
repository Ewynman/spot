# Diagram: App launch and authentication

## Purpose

Visualize cold start through session validation and main shell.

## Audience

Engineers, reviewers.

## Current status

Conceptual; align with `SpotApp`, `RootView`, and Supabase session APIs.

## Details

```mermaid
flowchart TD
  A[App launch] --> B[Detect installation state]
  B --> C[Retain device-local Keychain session]
  C --> D[Load local Supabase session]
  D --> E{Session exists?}
  E -->|No| F{Pending OTP recovery?}
  F -->|Yes| G[Resume email verification]
  F -->|No| H{Saved account hint?}
  H -->|Yes| I[Show Welcome back]
  H -->|No| J[Show editorial auth entry]
  E -->|Yes| K{Session expired?}
  K -->|Yes| L[Refresh session]
  L --> M{Refresh succeeds?}
  M -->|No| F
  M -->|Yes| N[Load profile]
  K -->|No| N
  N --> O{Profile complete?}
  O -->|No| P[Complete required account setup]
  O -->|Yes| Q[Enter main app]
  P --> Q
```

Authentication entry and new-device paths:

```mermaid
flowchart LR
  A[Option A editorial welcome] --> B[Create account]
  B --> C[Email + username + password]
  C --> D[Six-digit signup OTP]
  D --> E[Authenticated session]
  A --> F[Email login]
  A --> G[Sign in with Apple + nonce]
  H[New device] --> G
  H --> I[iCloud Password AutoFill]
  H -. future Supabase work .-> J[Passkey]
```

## Related docs

- [../engineering/networking-and-auth.md](../engineering/networking-and-auth.md)
- [../product/user-flows.md](../product/user-flows.md)

## Open questions / TODOs

- None.
