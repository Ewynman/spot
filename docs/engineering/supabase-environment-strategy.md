# Supabase Environment Strategy: Production and Non-Production Split

## Purpose

Define the strategy for splitting Spot's Supabase backend into separate **production** and **non-production** environments, ensuring data isolation between TestFlight releases and internal testing builds.

## Audience

Engineering team, infrastructure owners, release managers, and Cursor agents implementing the environment split.

## Quick Reference

| Item | Current State | Target State |
|------|--------------|--------------|
| **Supabase Projects** | 2 isolated projects | Keep staging and production isolated |
| **Firebase Builds (main)** | Use staging Supabase | Keep using staging Supabase |
| **TestFlight Builds (release/**)** | Use production Supabase | Keep using production Supabase |
| **Config Method** | Injected by GitHub Actions with guarded fallbacks | Keep project-ID artifact checks |
| **Schema Migrations** | Applied directly to production | Test in staging first, then production |
| **Data Isolation** | None (shared database) | Complete (separate databases) |
| **Implementation Status** | Not started | [See Phase 1](#phase-1-project-setup-week-1) |

## Before You Begin

### Prerequisites

- [ ] Access to Supabase dashboard with permission to create new projects
- [ ] GitHub repository admin access to add secrets
- [ ] Supabase MCP server configured (for migration management)
- [ ] Understand current CI/CD workflows ([deploy.yml](.github/workflows/deploy.yml), [testflight.yml](.github/workflows/testflight.yml))
- [ ] Review current Supabase configuration in [Info.plist](Spot/Info.plist) and [Supabase.swift](Spot/Supabase/Supabase.swift)

### Key Files to Review

| File | Purpose |
|------|---------|
| [Spot/Info.plist](../../Spot/Info.plist) | Current hardcoded Supabase configuration |
| [Spot/Supabase/Supabase.swift](../../Spot/Supabase/Supabase.swift) | Supabase client initialization |
| [.github/workflows/deploy.yml](../../.github/workflows/deploy.yml) | Firebase App Distribution build (will use staging) |
| [.github/workflows/testflight.yml](../../.github/workflows/testflight.yml) | TestFlight build (will use production) |
| [supabase/migrations/](../../supabase/migrations/) | Schema migrations to replicate |

## Current Status

**Environment routing implemented** — As of 2026-07-28, local DEBUG and Firebase App Distribution builds use staging (`aeurigbbohyxvtsfiyul`), while TestFlight/App Store builds use production (`gomdoguewaawdlvijahg`). The Firebase workflow rejects any non-staging project URL before building.

## Table of Contents

- [Decision Summary](#decision-summary)
- [Getting Started](#getting-started)
- [Executive Summary](#executive-summary)
- [Current State Analysis](#current-state-analysis)
- [Proposed Solution](#proposed-solution)
- [Implementation Strategy](#implementation-strategy)
  - [Phase 1: Project Setup](#phase-1-project-setup)
  - [Phase 2: iOS App Changes](#phase-2-ios-app-changes)
  - [Phase 3: CI/CD Pipeline Changes](#phase-3-cicd-pipeline-changes)
  - [Phase 4: Schema Migration Strategy](#phase-4-schema-migration-strategy)
  - [Phase 5: Testing and Validation](#phase-5-testing-and-validation)
  - [Phase 6: Documentation Updates](#phase-6-documentation-updates)
- [Alternative Approaches Considered](#alternative-approaches-considered)
- [Success Criteria](#success-criteria)
- [Risks and Mitigations](#risks-and-mitigations)
- [Cost Analysis](#cost-analysis)
- [Timeline and Phases](#timeline-and-phases)
- [Open Questions](#open-questions)
- [Related Documentation](#related-documentation)
- [Next Steps](#next-steps)
- [Appendices](#appendix-a-current-supabase-usage-audit)
  - [Appendix A: Current Supabase Usage Audit](#appendix-a-current-supabase-usage-audit)
  - [Appendix B: Migration Script Template](#appendix-b-migration-script-template)
  - [Appendix C: Environment Validation Checklist](#appendix-c-environment-validation-checklist)
  - [Appendix D: Implementation Notes for Cursor Agents](#appendix-d-implementation-notes-for-cursor-agents)

---

## Decision Summary

**Recommendation:** Implement a two-project Supabase environment strategy with build-time configuration injection via GitHub Actions.

**Key Benefits:**
- Complete data isolation between testing and production
- Safe schema migration testing in staging before production
- No risk of test data contaminating production queries
- Independent rate limits and quotas per environment

**Estimated Effort:** 4 weeks (6 phases)

**Cost Impact:** Additional Supabase project (free tier initially, or ~$25/month for Pro tier)

**Risk Level:** Low — implementation is incremental with rollback capability at each phase

---

## Getting Started

If you're ready to implement this strategy, follow this quick guide:

1. **Review this entire document** — especially the [Current State Analysis](#current-state-analysis) and [Implementation Strategy](#implementation-strategy)
2. **Complete prerequisites** — see [Before You Begin](#before-you-begin)
3. **Start with Phase 1** — [Project Setup](#phase-1-project-setup-week-1) to create the staging Supabase project
4. **Use the MCP** — Supabase MCP server (`plugin-supabase-supabase`) can automate schema replication and migration application
5. **Track progress** — Use the [Success Criteria](#success-criteria) checklist to validate each phase
6. **Refer to appendices** — [Migration Script Template](#appendix-b-migration-script-template) and [Environment Validation Checklist](#appendix-c-environment-validation-checklist) provide implementation scaffolding

**Implementation scope:** 6 phases covering project setup, iOS changes, CI/CD pipeline updates, migration strategy, testing, and documentation.

---

## Executive Summary

Currently, Spot uses a **single Supabase project** for all builds (Firebase App Distribution testing builds from `main` and TestFlight production builds from `release/**` branches). This means:

- Test data and production user data share the same database
- Internal testing can interfere with production users
- No safe environment for destructive testing or schema experiments
- Risk of accidentally affecting production data during development

This PRD proposes splitting into **two Supabase projects** with build-time environment selection:

| Environment | Build Pipeline | Branch | Distribution | Supabase Project |
|-------------|---------------|--------|--------------|------------------|
| **Non-Production** | Firebase App Distribution | `main` | Internal testers | New staging project |
| **Production** | TestFlight / App Store | `release/**` | Public users | Current project (migrated) |

---

## Current State Analysis

### Current Supabase Configuration

**Single Project Setup:**
- **Project Reference:** `aeurigbbohyxvtsfiyul`
- **Project Name:** "Spot"
- **Organization:** `mdnqvdzrrhjtaxbwnleq`
- **Configuration Location:** `Spot/Info.plist` → `Supabase` dictionary
- **Client Initialization:** `Spot/Supabase/Supabase.swift` (global `supabase` client)

**Hardcoded in Info.plist:**
```xml
<key>Supabase</key>
<dict>
    <key>anonKey</key>
    <string>sb_publishable_5IKZU3dDw6C0-V9lRPc7vw_z_v8a08G</string>
    <key>url</key>
    <string>https://aeurigbbohyxvtsfiyul.supabase.co</string>
</dict>
```

### Current Build Pipeline

**Non-Production (Testing):**
- **Workflow:** `.github/workflows/deploy.yml`
- **Trigger:** Merges/pushes to `main` branch
- **Distribution:** Firebase App Distribution
- **Build Type:** Ad Hoc signed
- **Auto-increments:** Build number in `CURRENT_PROJECT_VERSION`
- **Current Supabase:** Production project (shared with TestFlight)

**Production:**
- **Workflow:** `.github/workflows/testflight.yml`
- **Trigger:** Pushes to `release/**` branches
- **Distribution:** App Store Connect / TestFlight
- **Build Type:** App Store signed
- **Versioning:** Marketing version from branch name (e.g., `release/1.1.0` → version `1.1.0`)
- **Current Supabase:** Production project (shared with testing builds)

### Current Data Usage

The app uses Supabase for:

1. **Authentication:** `Supabase.auth` (email/password, OAuth)
2. **User Profiles:** `public.users` table with RLS
3. **Spots:** `public.spots`, `public.spot_images`, `public.vibe_tags`
4. **Social Graph:** `follows`, `follow_requests`, likes, bookmarks
5. **Feed:** RPC `get_home_feed_v1` with server-side signing
6. **Storage:** Private buckets (`pending_images`, `approved_spot_images`, `approved_profile_images`)
7. **Moderation:** Edge Function `moderate-image` with Azure Content Safety
8. **Publishing:** RPC `publish_spot_with_approved_media_assets_v1`

### Current Pain Points

1. **Data Contamination:** Test spots appear in production queries (or vice versa)
2. **No Safe Testing:** Cannot test destructive operations (account deletion, mass data operations) without affecting production
3. **Schema Migration Risk:** Cannot safely test migrations before applying to production
4. **Analytics Pollution:** Firebase Analytics and user metrics include test data
5. **Moderation Testing:** Cannot test moderation edge cases without creating real moderation events
6. **No Rollback Safety:** Schema changes immediately affect all users
7. **Auth Confusion:** Test accounts mixed with real user accounts

---

## Proposed Solution

### Two-Project Strategy

Create **two separate Supabase projects** with identical schemas but isolated data:

#### Project 1: Non-Production / Staging
- **Purpose:** Internal testing, QA, schema migration validation
- **Used By:** Firebase App Distribution builds from `main`
- **Data Policy:** Can be reset/cleared periodically; no production data
- **Schema:** Mirror of production (ahead during migration testing)
- **Users:** Test accounts only
- **Edge Functions:** Separate deployment (can test experimental features)

#### Project 2: Production
- **Purpose:** Real user data for TestFlight and App Store releases
- **Used By:** TestFlight builds from `release/**` branches
- **Data Policy:** Never cleared; full backups; strict change control
- **Schema:** Authoritative; changes applied after staging validation
- **Users:** Real users only
- **Edge Functions:** Production-only deployment with uptime monitoring

### Build-Time Environment Selection

Use **Xcode build configurations** or **preprocessor macros** to select the correct Supabase project at build time:

```swift
// Spot/Utils/SupabaseEnvironment.swift (proposed)
import Foundation

enum SupabaseEnvironment {
    case production
    case staging
    
    static var current: SupabaseEnvironment {
        #if PRODUCTION_BUILD
        return .production
        #else
        return .staging
        #endif
    }
    
    var url: String {
        switch self {
        case .production:
            return "https://PROD_PROJECT.supabase.co"
        case .staging:
            return "https://STAGING_PROJECT.supabase.co"
        }
    }
    
    var anonKey: String {
        switch self {
        case .production:
            return "PROD_ANON_KEY"
        case .staging:
            return "STAGING_ANON_KEY"
        }
    }
}
```

**Alternative Approach:** Inject environment-specific `Info.plist` files during CI/CD:
- Keep base `Info.plist` in source control with placeholders
- GitHub Actions injects correct values from secrets before build
- More secure (keys never in source control, even for staging)

---

## Implementation Strategy

### Phase 1: Project Setup

1. **Create Staging Supabase Project**
   - Use Supabase MCP or dashboard to create new project
   - Name: "Spot Staging" or "Spot Non-Production"
   - Same organization as production project
   - Document project ref, URL, and anon key in **secure location** (not in repo)

2. **Replicate Schema to Staging**
   - Export current schema from production: `supabase db dump`
   - Apply all migrations from `supabase/migrations/` to staging project
   - Verify schema parity: tables, columns, indexes, RLS policies, functions, triggers

3. **Configure Storage Buckets**
   - Create matching buckets: `pending_images`, `approved_spot_images`, `approved_profile_images`
   - Apply same RLS policies from production
   - Test upload/download with signed URLs

4. **Deploy Edge Functions to Staging**
   - Deploy `moderate-image` function to staging project
   - Configure separate Azure Content Safety endpoint (or shared dev endpoint)
   - Test moderation pipeline end-to-end

5. **Seed Staging Data**
   - Create test user accounts (5-10 accounts with various states)
   - Create test spots across different vibes, locations, privacy settings
   - Create test follow relationships and blocked users
   - Create Pro subscription test accounts (StoreKit sandbox)

### Phase 2: iOS App Changes

1. **Add Build Configuration Support**
   ```swift
   // Option A: Swift preprocessor flags
   #if PRODUCTION_BUILD
   let supabaseURL = "https://PROD.supabase.co"
   let supabaseKey = "PROD_KEY"
   #else
   let supabaseURL = "https://STAGING.supabase.co"
   let supabaseKey = "STAGING_KEY"
   #endif
   ```

2. **Update Client Initialization**
   - Modify `Spot/Supabase/Supabase.swift` to use environment-based config
   - Update all services to use the singleton `supabase` client (no changes needed if they already do)
   - Add logging to show which environment is active on launch (DEBUG builds only)

3. **Update Info.plist Strategy**
   - **Option A:** Keep one Info.plist with preprocessor macros
   - **Option B:** Create separate Info-Staging.plist and Info-Production.plist
   - **Option C:** Inject via CI/CD (recommended for security)

4. **Add Environment Indicator (DEBUG only)**
   ```swift
   #if DEBUG
   // Show banner or log indicating staging vs production
   SpotLogger.log(.info, "Supabase Environment: \(SupabaseEnvironment.current)")
   #endif
   ```

### Phase 3: CI/CD Pipeline Changes

#### Firebase Deploy Workflow (Non-Production)

Update `.github/workflows/deploy.yml`:

```yaml
- name: Install Supabase Configuration (Staging)
  env:
    SUPABASE_STAGING_URL: ${{ secrets.SUPABASE_STAGING_URL }}
    SUPABASE_STAGING_ANON_KEY: ${{ secrets.SUPABASE_STAGING_ANON_KEY }}
  run: |
    # Inject staging Supabase config into Info.plist
    /usr/libexec/PlistBuddy -c "Set :Supabase:url ${SUPABASE_STAGING_URL}" Spot/Info.plist
    /usr/libexec/PlistBuddy -c "Set :Supabase:anonKey ${SUPABASE_STAGING_ANON_KEY}" Spot/Info.plist

- name: Build app
  run: |
    xcodebuild \
      -scheme Spot \
      -destination "generic/platform=iOS" \
      -archivePath $RUNNER_TEMP/Spot.xcarchive \
      -configuration Release \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      OTHER_SWIFT_FLAGS="-D STAGING_BUILD" \
      clean archive | xcbeautify
```

#### TestFlight Workflow (Production)

Update `.github/workflows/testflight.yml`:

```yaml
- name: Install Supabase Configuration (Production)
  env:
    SUPABASE_PRODUCTION_URL: ${{ secrets.SUPABASE_PRODUCTION_URL }}
    SUPABASE_PRODUCTION_ANON_KEY: ${{ secrets.SUPABASE_PRODUCTION_ANON_KEY }}
  run: |
    # Inject production Supabase config into Info.plist
    /usr/libexec/PlistBuddy -c "Set :Supabase:url ${SUPABASE_PRODUCTION_URL}" Spot/Info.plist
    /usr/libexec/PlistBuddy -c "Set :Supabase:anonKey ${SUPABASE_PRODUCTION_ANON_KEY}" Spot/Info.plist

- name: Build and export production archive
  run: |
    xcodebuild \
      -scheme Spot \
      -destination "generic/platform=iOS" \
      -archivePath $RUNNER_TEMP/Spot.xcarchive \
      -configuration Release \
      MARKETING_VERSION="$MARKETING_VERSION" \
      CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      OTHER_SWIFT_FLAGS="-D PRODUCTION_BUILD" \
      clean archive | xcbeautify
```

#### GitHub Secrets to Add

In GitHub Repository Settings → Secrets and variables → Actions ([GitHub documentation](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)):

| Secret Name | Environment | Description |
|-------------|-------------|-------------|
| `SUPABASE_STAGING_URL` | Non-Production | Staging project URL |
| `SUPABASE_STAGING_ANON_KEY` | Non-Production | Staging anon/publishable key |
| `SUPABASE_PRODUCTION_URL` | Production | Production project URL |
| `SUPABASE_PRODUCTION_ANON_KEY` | Production | Production anon/publishable key |

**Note:** These secrets will be injected into `Info.plist` during the build process, replacing the currently hardcoded values.

### Phase 4: Schema Migration Strategy

1. **Test-First Migration Flow**
   ```
   1. Write migration SQL in supabase/migrations/
   2. Apply to STAGING via Supabase MCP or CLI
   3. Run full test suite against staging
   4. Validate data integrity, RLS policies, query performance
   5. If successful, apply SAME migration to PRODUCTION
   6. Monitor production for errors/performance issues
   ```

2. **Migration Automation**
   - Use Supabase MCP `apply_migration` for both environments
   - Document rollback procedures for each migration
   - Maintain migration log with staging/production application dates

3. **Schema Drift Prevention**
   - Weekly schema comparison: `supabase db diff --linked --schema public`
   - Alert on unexpected drift between staging and production
   - Document intentional differences (e.g., test-only functions)

### Phase 5: Testing and Validation

1. **Staging Environment Tests**
   - [ ] Auth flow: signup, login, password reset
   - [ ] Spot creation with moderation pipeline
   - [ ] Feed loading with signed image URLs
   - [ ] Search across users, spots, vibes
   - [ ] Follow/unfollow, private accounts
   - [ ] Block/report flows
   - [ ] Pro subscription mock (StoreKit sandbox)
   - [ ] Account deletion
   - [ ] Universal Links and deep links

2. **Production Validation**
   - [ ] Smoke test on TestFlight build
   - [ ] Verify production data is isolated from staging
   - [ ] Monitor Supabase dashboard: query performance, error rates
   - [ ] Check Firebase Analytics: no staging data in production reports

3. **CI/CD Validation**
   - [ ] Merge to `main` → Firebase build uses staging
   - [ ] Push to `release/1.x.x` → TestFlight build uses production
   - [ ] Verify no accidental cross-contamination

### Phase 6: Documentation Updates

Update the following documentation:

1. **docs/engineering/supabase.md**
   - Document two-project setup
   - Explain environment selection logic
   - Update "Local vs production" section

2. **docs/engineering/environment-variables.md**
   - Add staging and production Supabase config entries
   - Document GitHub Secrets requirements

3. **docs/engineering/database-and-rls.md**
   - Update migration workflow to include staging-first strategy
   - Document schema parity validation process

4. **.github/workflows/README.md**
   - Document new Supabase secrets
   - Explain environment injection steps

5. **README.md (root)**
   - Update Quick Start to mention environment setup
   - Link to this environment strategy doc

6. **docs/README.md**
   - Add link to this document in Engineering section

---

## Alternative Approaches Considered

### Single Project with Namespace Prefixes

**Approach:** Use a single Supabase project but prefix all data with environment tags.

**Example:**
- Tables: Keep shared schema
- Data: Add `environment` column (`'staging'` or `'production'`)
- RLS: Filter queries by `environment` value

**Pros:**
- Single project to manage
- Easier schema migrations (one update)
- Lower cost (one project)

**Cons:**
- High risk of data leakage (RLS mistakes expose all data)
- Shared rate limits and quotas
- Cannot test destructive operations safely
- Analytics still mixed
- No isolation for Edge Functions
- Complex RLS policies increase attack surface

**Decision:** **Rejected** — Risk of cross-contamination too high for production user data.

---

### Separate Projects with Manual Sync

**Approach:** Two projects but manually replicate schema changes.

**Pros:**
- Full isolation
- Independent scaling and quotas

**Cons:**
- Schema drift inevitable without automation
- Manual process error-prone
- No forcing function to test staging first

**Decision:** **Accepted with automation** — Automation via Supabase MCP and CI/CD mitigates drift risk.

---

### Three Environments (Dev, Staging, Production)

**Approach:** Add a third local development project.

**Pros:**
- Local development doesn't affect staging or production
- Faster iteration for schema experiments

**Cons:**
- Increased complexity
- Three projects to maintain schema parity
- Higher cost
- Local Supabase CLI already provides local-only development

**Decision:** **Deferred** — Start with two environments; revisit if local Supabase adoption increases.

---

## Success Criteria

### Functional Requirements

- [ ] Firebase App Distribution builds connect to staging Supabase project
- [ ] TestFlight builds connect to production Supabase project
- [ ] No staging data in production database
- [ ] No production data in staging database
- [ ] All migrations tested in staging before production
- [ ] Schema parity maintained between environments
- [ ] CI/CD automatically injects correct configuration
- [ ] No secrets committed to source control

### Non-Functional Requirements

- [ ] Zero downtime during migration
- [ ] No user impact (production users unaffected by staging tests)
- [ ] Migration completed within 4 weeks
- [ ] Rollback plan documented for each phase
- [ ] Performance unchanged (no additional latency from environment logic)

### Documentation Requirements

- [ ] All engineering docs updated with environment strategy
- [ ] Runbook created for environment management
- [ ] Migration workflow documented for future schema changes
- [ ] Troubleshooting guide for environment-specific issues

---

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Schema drift** between environments | High | Medium | Automated schema comparison in CI; weekly drift reports |
| **Secrets leak** in GitHub Actions logs | High | Low | Use GitHub Actions secret masking; audit logs quarterly |
| **Wrong environment** config in production build | High | Low | CI validation step: check URLs before upload; manual verification checklist |
| **Staging data** mixed into production during migration | High | Low | Dry-run migration validation; separate migration windows; schema-only migrations first |
| **Increased cost** from two projects | Medium | High | Expected; budget for 2x Supabase project costs; evaluate free tier limits |
| **Edge Function** staging deployment fails | Medium | Medium | Separate Azure credentials for staging; test deployment in Phase 1 |
| **Migration breaks** production | High | Low | Staging-first testing; canary rollout; documented rollback SQL |
| **Developer confusion** about which environment is active | Low | Medium | Clear logging in DEBUG builds; environment indicator in app (staging only) |

---

## Cost Analysis

### Current State

- **Supabase:** 1 project (current plan: contact team to verify free/pro tier status)
- **Firebase:** 1 project for both environments (Analytics, Crashlytics)
- **GitHub Actions:** Current usage can be viewed in repository Insights → Actions

### Proposed State

- **Supabase:** 2 projects (staging + production)
  - **Staging:** Start with free tier if usage is low; upgrade to Pro tier if needed
  - **Production:** Current plan (no change)
  - **Estimated increase:** $0-$25/month depending on staging usage
- **Firebase:** 1 project (no change)
- **GitHub Actions:** Same (no additional workflow runs)

### Budget Recommendation

- **Minimum:** Keep staging on free tier, upgrade if needed
- **Recommended:** Pro tier for both environments for consistent feature set

---

## Timeline and Phases

This implementation is structured into 6 phases. Each phase builds on the previous one and has clear deliverables. Phases can be implemented sequentially or with some overlap.

| Phase | Key Deliverables | Dependencies |
|-------|------------------|--------------|
| **Phase 1: Project Setup** | Staging project created, schema replicated, Edge Functions deployed, test data seeded | Supabase dashboard access, MCP configured |
| **Phase 2: iOS App Changes** | Environment selection logic implemented, client initialization updated | Phase 1 complete |
| **Phase 3: CI/CD Pipeline** | GitHub Actions updated, secrets configured, automated environment injection | Phase 2 complete |
| **Phase 4: Migration Strategy** | Test-first migration flow documented and automated | Phase 3 complete |
| **Phase 5: Testing** | End-to-end validation, smoke tests, production verification | Phase 4 complete |
| **Phase 6: Documentation** | All docs updated, runbooks created, team trained | Phase 5 complete |

**Implementation approach:** Each phase should be fully completed and validated before proceeding to the next. Phases 2 and 3 can partially overlap if needed.

---

## Open Questions

1. **Supabase Plan:** What is the current Supabase plan (Free, Pro, Team, Enterprise)? Does staging need Pro tier?
2. **Azure Credentials:** Should staging use separate Azure Content Safety credentials or shared dev endpoint?
3. **Data Seeding:** Should staging be seeded with production-like data volume for load testing?
4. **StoreKit:** Does StoreKit sandbox work correctly with staging Supabase project?
5. **Universal Links:** Do Universal Links need separate AASA files for staging app?
6. **Firebase Projects:** Should staging use a separate Firebase project for Analytics/Crashlytics?
7. **Local Development:** Should developers be encouraged to use local Supabase CLI instead of staging?
8. **Migration Cutover:** Should production migration be the original project or new project? (Recommend: keep production as-is, create new staging)

---

## Related Documentation

- [docs/engineering/supabase.md](supabase.md) — Supabase role in architecture
- [docs/engineering/data-plane.md](data-plane.md) — Data plane policy (Supabase only)
- [docs/engineering/environment-variables.md](environment-variables.md) — Configuration secrets
- [docs/engineering/database-and-rls.md](database-and-rls.md) — Schema and RLS
- [docs/engineering/ci-cd.md](ci-cd.md) — GitHub Actions workflows
- [.github/workflows/README.md](../../.github/workflows/README.md) — Workflow documentation

---

## Next Steps

1. **Approve PRD:** Review this document with team and stakeholders
2. **Create Staging Project:** Use Supabase MCP or dashboard
3. **Assign Ownership:** Designate environment strategy owner
4. **Schedule Implementation:** Block 4-week window for migration
5. **Create Tracking Issue:** GitHub issue with checklist for all phases
6. **Budget Approval:** Confirm budget for second Supabase project

---

## Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-07-06 | Cursor Agent | Initial PRD from discovery work |

---

## Appendix A: Current Supabase Usage Audit

### Tables in Use

```
public.users
public.spots
public.spot_images
public.vibe_tags
public.follows
public.follow_requests
public.spot_likes
public.spot_bookmarks
public.user_feed_events
public.reports
public.user_blocks
public.user_terms_acceptances
public.terms_versions
public.moderation_events
public.content_moderation_results
public.media_assets
public.media_moderation_events
public.spot_vibe_tags
public.bookmark_collections (legacy)
public.bookmark_collection_spots (legacy)
```

### RPCs in Use

```sql
get_home_feed_v1
publish_spot_with_approved_media_assets_v1
submit_content_report
record_terms_acceptance
delete_my_account
sync_current_user (security definer)
```

### Edge Functions

```
moderate-image (in supabase/functions/moderate-image/)
```

### Storage Buckets

```
spots (legacy private bucket for older spot images)
pending_images (moderation queue - pre-approval)
approved_spot_images (post-moderation approved spot images)
approved_profile_images (post-moderation approved profile pictures)
```

All buckets are private with RLS policies enforced (see `20260504100000_image_moderation_azure_v1.sql`).

### Authentication Methods

- Email/Password (primary)
- Sign in with Apple (verified - implemented in `AuthViewModel.swift` and `ThemedAppleSignInButton.swift`)
- OAuth providers: None currently enabled (no Google, GitHub, or Facebook providers configured in migrations)

---

## Appendix B: Migration Script Template

```sql
-- Template for migrations that need to run in both staging and production

-- Migration: [DESCRIPTIVE_NAME]
-- Applied to staging: YYYY-MM-DD
-- Applied to production: YYYY-MM-DD
-- Author: [NAME]
-- Rollback: [LINK TO ROLLBACK SQL OR DESCRIPTION]

BEGIN;

-- 1. Schema changes (DDL)
-- Example: ALTER TABLE, CREATE TABLE, etc.

-- 2. Data migrations (DML)
-- Example: UPDATE, INSERT, etc.

-- 3. RLS policy changes
-- Example: CREATE POLICY, ALTER POLICY, etc.

-- 4. Grants and permissions
-- Example: GRANT, REVOKE

-- 5. Validation queries (commented out)
-- SELECT count(*) FROM new_table;
-- SELECT * FROM pg_policies WHERE tablename = 'new_table';

COMMIT;

-- Rollback script (commented out)
-- BEGIN;
-- DROP TABLE IF EXISTS new_table CASCADE;
-- COMMIT;
```

---

## Appendix C: Environment Validation Checklist

Use this checklist before releasing to production:

### Pre-Flight Checks

- [ ] Confirm Supabase URL in build matches expected environment
- [ ] Verify anon key is correct for environment
- [ ] Check Firebase project ID (if separate projects)
- [ ] Validate Universal Link configuration
- [ ] Test auth flow (signup, login, password reset)
- [ ] Verify RLS policies are identical in staging and production
- [ ] Check Edge Function deployment status
- [ ] Confirm storage bucket policies match

### Post-Deployment Validation

- [ ] Monitor Supabase dashboard for error spikes
- [ ] Check Firebase Crashlytics for new crashes
- [ ] Verify feed loads with correct environment data
- [ ] Test spot creation and publishing
- [ ] Validate image uploads and signed URLs
- [ ] Check moderation pipeline is working
- [ ] Monitor query performance (no regressions)
- [ ] Verify no staging data leaking into production

---

**End of PRD**

---

## Appendix D: Implementation Notes for Cursor Agents

When implementing this environment strategy as a Cursor agent, follow these guidelines:

### Using Supabase MCP

1. **List projects:** Use `list_projects` to discover the current production project
2. **Create staging project:** Use MCP tools to create a new project in the same organization
3. **Schema replication:** Use `execute_sql` or `apply_migration` to replicate schema from production to staging
4. **Verify schema parity:** Compare tables, policies, functions, and triggers between environments

### Key Considerations

- **Never expose service role keys** — only add anon/publishable keys to GitHub secrets
- **Test migrations in staging first** — always validate with `get_advisors` before applying to production
- **Use environment-specific secrets** — ensure GitHub Actions use the correct `SUPABASE_*_URL` and `SUPABASE_*_ANON_KEY` per workflow
- **Update Info.plist via CI** — do not hardcode staging credentials in source control
- **Validate RLS policies** — ensure all policies are identical between staging and production after replication

### Implementation Order

1. Start with Phase 1 (Project Setup) — this can be done independently
2. Phase 2 (iOS changes) requires careful review of `Spot/Supabase/Supabase.swift`
3. Phase 3 (CI/CD) must update both `.github/workflows/deploy.yml` and `.github/workflows/testflight.yml`
4. Test thoroughly in Phase 5 before considering complete

### Documentation Updates Required

After implementation, update:
- `docs/engineering/supabase.md` — add environment split details
- `docs/engineering/environment-variables.md` — document new GitHub secrets
- `docs/engineering/database-and-rls.md` — update migration workflow
- `docs/engineering/local-setup.md` — explain how to configure local environment
- This file — update implementation status to "Complete" and add actual dates

---

**End of Document**
