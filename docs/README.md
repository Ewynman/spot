# Spot documentation

## Purpose

Central index for Spot product, engineering, diagram, and operations documentation.

## Audience

New developers, reviewers, release owners, support, and Cursor agents.

## Current status

Code and workflow behavior were re-audited on **2026-08-06** (coverage scope, Services folder mirror, SpotTests layout). Remaining unknowns are explicitly marked; verified implementation gaps are documented as limitations rather than target behavior.

## Details

### Start here

1. Read the [root README](../README.md) for a one-minute overview, quick start, and links.
2. Skim [`Spot/README.md`](../Spot/README.md) for the app source map.
3. Pick a reading path below.

### Product

| Doc | Topics |
| --- | --- |
| [product/overview.md](product/overview.md) | What Spot is, surfaces, principles |
| [product/terminology.md](product/terminology.md) | Shared vocabulary |
| [product/user-flows.md](product/user-flows.md) | Primary journeys + Mermaid |
| [product/auth-reliability-prd.md](product/auth-reliability-prd.md) | **P0 release requirements for signup, verification, login, and session continuity** |
| [product/internal-test-email-verification-prd.md](product/internal-test-email-verification-prd.md) | Staging-only internal `UT####` verification requirements |
| [operations/staging-internal-email-verification.md](operations/staging-internal-email-verification.md) | How to enable/rotate staging internal verification secrets |
| [product/onboarding.md](product/onboarding.md) | First-run and home tour |
| [product/posting-flow.md](product/posting-flow.md) | Create and publish Spots |
| [product/map-experience.md](product/map-experience.md) | Map, pins, spot drawer |
| [product/home-feed.md](product/home-feed.md) | Feed purpose and ranking |
| [product/search-experience.md](product/search-experience.md) | Search segments, grids, privacy, Pro filters |
| [product/profiles-and-social.md](product/profiles-and-social.md) | Profiles, follows, privacy |
| [product/pro-subscription.md](product/pro-subscription.md) | Pro / StoreKit |
| [product/support-and-policies.md](product/support-and-policies.md) | Support and policy surfaces |

### Engineering

| Doc | Topics |
| --- | --- |
| [engineering/architecture.md](engineering/architecture.md) | Modules, data flow, integrations |
| [engineering/runtime-flows.md](engineering/runtime-flows.md) | **Code-verified runtime flows, source map, and known limitations** |
| [engineering/local-setup.md](engineering/local-setup.md) | Xcode, schemes, simulator |
| [engineering/environment-variables.md](engineering/environment-variables.md) | Config keys (no secrets) |
| [engineering/configuration.md](engineering/configuration.md) | Info.plist, entitlements |
| [engineering/logging.md](engineering/logging.md) | SpotLogger, debug categories |
| [engineering/notifications.md](engineering/notifications.md) | Local notifications and remote-push gaps |
| [engineering/networking-and-auth.md](engineering/networking-and-auth.md) | Sessions, RLS expectations |
| [engineering/supabase.md](engineering/supabase.md) | Supabase role in the app |
| [engineering/supabase-environment-strategy.md](engineering/supabase-environment-strategy.md) | **Production and non-production environment split strategy** |
| [engineering/supabase-environment-setup-guide.md](engineering/supabase-environment-setup-guide.md) | **Step-by-step setup instructions for two-environment strategy** |
| [engineering/data-plane.md](engineering/data-plane.md) | **Supabase-only data plane; Firebase observability only** |
| [engineering/database-and-rls.md](engineering/database-and-rls.md) | RLS principles, migrations |
| [engineering/production-readiness-audit-2026-05.md](engineering/production-readiness-audit-2026-05.md) | Pre-launch audit: leaks, feed variety, follows |
| [engineering/storage-and-media.md](engineering/storage-and-media.md) | Buckets, uploads |
| [engineering/image-moderation.md](engineering/image-moderation.md) | Moderation pipeline |
| [engineering/ugc-moderation.md](engineering/ugc-moderation.md) | UGC moderation, reporting, blocking, Terms (Guideline 1.2) |
| [engineering/universal-links.md](engineering/universal-links.md) | Deep links and Universal Links |
| [engineering/testing.md](engineering/testing.md) | Schemes, unit vs UI tests |
| [testing/private-account-tests.md](testing/private-account-tests.md) | Private account test suite |
| [engineering/ci-cd.md](engineering/ci-cd.md) | GitHub Actions CI/CD, Xcode Cloud disabled |
| [engineering/release-process.md](engineering/release-process.md) | Pre-release and App Store |
| [engineering/firebase-distribution-setup.md](engineering/firebase-distribution-setup.md) | Firebase App Distribution setup |
| [engineering/location-selection-improvements.md](engineering/location-selection-improvements.md) | Location selection implementation notes |
| [engineering/troubleshooting.md](engineering/troubleshooting.md) | Common failures |

### Diagrams

| Doc | Contents |
| --- | --- |
| [diagrams/README.md](diagrams/README.md) | Index of flow diagrams |
| [diagrams/app-launch-auth-flow.md](diagrams/app-launch-auth-flow.md) | Launch and session |
| [diagrams/onboarding-flow.md](diagrams/onboarding-flow.md) | Onboarding |
| [diagrams/posting-flow.md](diagrams/posting-flow.md) | Posting and moderation |
| [diagrams/image-moderation-flow.md](diagrams/image-moderation-flow.md) | Moderation sequence |
| [diagrams/map-spot-drawer-flow.md](diagrams/map-spot-drawer-flow.md) | Map drawer state |
| [diagrams/universal-links-flow.md](diagrams/universal-links-flow.md) | Universal Links sequence |
| [diagrams/supabase-rls-flow.md](diagrams/supabase-rls-flow.md) | RLS decision flow |
| [diagrams/subscription-flow.md](diagrams/subscription-flow.md) | Pro purchase flow |
| [diagrams/testing-release-flow.md](diagrams/testing-release-flow.md) | Test and release pipeline |

### Operations

| Doc | Topics |
| --- | --- |
| [operations/runbooks.md](operations/runbooks.md) | Routine checks |
| [operations/incident-response.md](operations/incident-response.md) | Severity and response |
| [operations/app-store-review-notes.md](operations/app-store-review-notes.md) | Review-facing notes |
| [operations/app-store-rejection-july-2026-fix-guide.md](operations/app-store-rejection-july-2026-fix-guide.md) | Historical July 2026 rejection remediation |
| [operations/documentation-audit-2026-07.md](operations/documentation-audit-2026-07.md) | **Code/docs audit, external verification, known implementation gaps** |
| [operations/documentation-maintenance.md](operations/documentation-maintenance.md) | When to update docs |

### Suggested reading paths

**New developer:** [local-setup](engineering/local-setup.md) → [architecture](engineering/architecture.md) → [runtime flows](engineering/runtime-flows.md) → [testing](engineering/testing.md) → [product overview](product/overview.md).

**Cursor agent:** [.cursor/rules/project.mdc](../.cursor/rules/project.mdc) → [data-plane](engineering/data-plane.md) → [runtime flows](engineering/runtime-flows.md) → [networking-and-auth](engineering/networking-and-auth.md) → [database-and-rls](engineering/database-and-rls.md) → [universal-links](engineering/universal-links.md).

**Release owner:** [release-process](engineering/release-process.md) → [runbooks](operations/runbooks.md) → [app-store-review-notes](operations/app-store-review-notes.md) → [troubleshooting](engineering/troubleshooting.md).

**Security / review:** [networking-and-auth](engineering/networking-and-auth.md) → [database-and-rls](engineering/database-and-rls.md) → [image-moderation](engineering/image-moderation.md) → [incident-response](operations/incident-response.md).

### Documentation maintenance

See [operations/documentation-maintenance.md](operations/documentation-maintenance.md) for PR checklist and when to update diagrams.

## Related docs

- [Root README](../README.md)
- [Cursor project rules](../.cursor/rules/project.mdc)

## Open questions / TODOs

- Pricing and App Store Connect metadata: confirm with owner where marked in Pro and review docs.
