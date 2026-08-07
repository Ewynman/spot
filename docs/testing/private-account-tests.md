# Private Account Testing Suite

This document describes the comprehensive test suite for private account functionality in Spot.

## Overview

The private account testing suite ensures that all privacy features work correctly, including:
- Private account settings
- Follow request creation, acceptance, and denial
- Content visibility based on privacy settings and follow state
- Privacy cache behavior and performance
- Integration with feed, search, map, and profile features

## Test Files

### Unit Tests (SpotTests)

All unit tests use the Swift Testing framework and can be run via the `SpotTests` scheme.

#### AuthorPrivacyCacheTests.swift
Tests the `AuthorPrivacyCache` actor that manages privacy filtering.

**Coverage:**
- Cache lifecycle (clear, invalidate, TTL)
- Follow relationship changes
- Spot filtering based on privacy settings
- Concurrent access and thread safety
- Edge cases (invalid UUIDs, duplicate authors, etc.)

**Key Tests:**
- `testFilterSpotsWithNoUserId` - Ensures spots without user IDs are filtered
- `testConcurrentFilterCalls` - Validates actor concurrency safety
- `testWarmCacheWithLargeAuthorSet` - Tests chunking behavior (10 per batch)
- `testFilterPreservesSpotProperties` - Ensures filtering preserves data integrity

#### FollowRequestsServiceTests.swift
Tests the `FollowRequestsService` that handles follow request operations.

**Coverage:**
- Follow request counting
- Pagination (fetchPage with start/pageSize)
- Accept and deny operations
- Input validation (invalid/empty/malformed UUIDs)
- FollowRequest and Page model structures
- Concurrent operations
- Edge cases (whitespace UIDs, very long strings, etc.)

**Key Tests:**
- `testAcceptWithInvalidRequesterUid` - Validates error handling
- `testFetchPagePaginationLogic` - Tests pagination correctness
- `testConcurrentCountCalls` - Validates thread safety
- `testFollowRequestHashable` - Ensures model is usable in Sets

#### PrivateAccountIntegrationTests.swift
Documents expected behavior for end-to-end private account flows.

**Coverage:**
- Private/public account conversion flows
- Follow request lifecycle (send, accept, deny)
- Content visibility rules across feed, search, map, profile
- Cache invalidation triggers
- Blocking interactions
- Notification delivery
- Data consistency (database and cache sync)
- Race conditions and concurrent operations
- Performance considerations

**Note:** Many tests in this suite are documented flows (using `#expect(true, "Documented: ...")`) that describe expected behavior for integration testing or future implementation of more comprehensive tests with mocked dependencies.

### UI Tests (SpotUITests)

UI tests use XCTest and XCUITest frameworks and can be run via the `SpotUITests` scheme.

#### PrivateAccountUITests.swift
Tests user interactions with private account features.

**Coverage:**
- Privacy settings navigation and toggle
- Follow requests list (view, accept, deny, empty state)
- Private profile views (self, follower, non-follower)
- Follow actions (request to follow, cancel request, unfollow)
- Feed/search/map integration with privacy filtering
- Notifications (follow request received, accepted)
- Loading and error states
- Pagination
- Accessibility features
- Edge cases (offline, rapid actions, real-time updates)

**Note:** These tests are documented as expected UI behavior. To implement them fully, you'll need:
- Test fixtures/mock data
- UI accessibility identifiers on key elements
- Proper test environment setup with test accounts

## Running the Tests

### Prerequisites
- Xcode 15.0 or later
- iOS 15.0+ simulator or device
- `xcbeautify` (optional, for pretty output)

### Running Unit Tests

```bash
# Find an available iPhone simulator
SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')

# Check if xcbeautify is installed
BEAUTIFY=$(command -v xcbeautify >/dev/null && echo "xcbeautify" || echo "cat")

# Run all unit tests (SpotTests scheme)
xcodebuild -scheme SpotTests -destination "id=$SIM_ID" test | $BEAUTIFY

# Run specific test suite
xcodebuild -scheme SpotTests -destination "id=$SIM_ID" test -only-testing:SpotTests/AuthorPrivacyCacheTests | $BEAUTIFY

# Run specific test
xcodebuild -scheme SpotTests -destination "id=$SIM_ID" test -only-testing:SpotTests/AuthorPrivacyCacheTests/testFilterSpotsWithEmptyArray | $BEAUTIFY
```

### Running UI Tests

```bash
# Run all UI tests (SpotUITests scheme)
xcodebuild -scheme SpotUITests -destination "id=$SIM_ID" test | $BEAUTIFY

# Run private account UI tests specifically
xcodebuild -scheme SpotUITests -destination "id=$SIM_ID" test -only-testing:SpotUITests/PrivateAccountUITests | $BEAUTIFY
```

### Running All Tests

```bash
# Run both unit and UI tests (Spot scheme with test plan)
xcodebuild -scheme Spot -destination "id=$SIM_ID" test | $BEAUTIFY
```

### With Code Coverage

```bash
xcodebuild -scheme SpotTests -destination "id=$SIM_ID" test -enableCodeCoverage YES | $BEAUTIFY
```

## Test Schemes

The project has three test schemes:

1. **Spot** - Runs both SpotTests and SpotUITests (uses `Spot.xctestplan`)
   - Includes all unit tests (parallelizable)
   - Includes all UI tests (non-parallelizable)

2. **SpotTests** - Runs only unit tests
   - Fast execution
   - No UI dependencies
   - Parallelizable

3. **SpotUITests** - Runs only UI tests (uses `SpotUITests.xctestplan`)
   - Tests user interactions
   - Requires simulator/device
   - Non-parallelizable

## Test Environment

### Unit Tests
- Use isolated `UserDefaults` via `SpotTestHelpers.makeIsolatedDefaults()`
- Use `SpotTestHelpers.makeSpot()` for fixture generation
- Do NOT require live Supabase connection
- Do NOT trigger Sign in with Apple or StoreKit prompts
- Mock authentication state where needed

### UI Tests
- Use `--uitesting` launch argument
- Apply test configuration via `SpotUITestAppConfiguration`
- May require test accounts for full integration testing
- Use accessibility identifiers for stable element selection

## Coverage Goals

For new production code related to private accounts:
- **Unit tests:** Happy path, empty/error branches, guard rules
- **UI tests:** Critical user flows (view private profile, send/accept follow request)

Aim for meaningful tests that catch real bugs, not just high coverage numbers.

## Test Maintenance

When adding private account features:
1. Add unit tests for new service methods
2. Add UI tests for new user-facing flows
3. Update integration tests documentation
4. Verify cache invalidation happens correctly
5. Test privacy filtering in all discovery surfaces (feed, map, search)

## Known Limitations

1. **Network dependency:** Some tests may fail without Supabase connectivity
   - Tests are designed to handle network errors gracefully
   - Invalid UUID tests return 0/empty without network calls

2. **Authentication state:** Most tests run without authenticated user
   - Privacy cache returns `true` or `nil` for unknown viewers
   - Full integration tests would require test user setup

3. **UI test implementation:** UI tests are documented but not fully implemented
   - Requires accessibility identifiers to be added to views
   - Requires test fixtures or mock data setup
   - Consider implementing as you build features

## Future Enhancements

1. **Mock Supabase client** - For testing without network dependency
2. **Test user factory** - Create and manage test accounts programmatically
3. **Implement full UI test scenarios** - Beyond documentation
4. **Performance benchmarks** - Measure cache performance with large datasets
5. **Visual regression testing** - Screenshot comparison for UI tests
6. **Accessibility audit** - Comprehensive VoiceOver/Dynamic Type testing

## Related Documentation

- `docs/engineering/database-and-rls.md` - RLS policies for private accounts
- `docs/engineering/networking-and-auth.md` - Authentication flow
- `Spot/Services/Social/AuthorPrivacyCache.swift` - Privacy cache implementation
- `Spot/Services/Social/FollowRequestsService.swift` - Follow request logic
