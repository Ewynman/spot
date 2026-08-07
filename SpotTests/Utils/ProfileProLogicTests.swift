import Foundation
import Testing
@testable import Spot

struct SettingsDateFormatterTests {
    @Test func formatsMediumDateWithoutTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let formatted = SettingsDateFormatter.mediumDate(date)
        #expect(formatted.contains("2026"))
        #expect(formatted.contains("6") || formatted.contains("06"))
    }
}

struct SpotListDeduperTests {
    @Test func acceptsNewIdsAndSkipsDuplicatesAndNil() {
        var known = Set<String>()
        let first = SpotListDeduper.accepting(
            [
                SpotTestHelpers.makeSpot(id: "a"),
                SpotTestHelpers.makeSpot(id: nil),
                SpotTestHelpers.makeSpot(id: "b")
            ],
            into: &known
        )
        #expect(first.map(\.id) == ["a", "b"])
        #expect(known == ["a", "b"])

        let second = SpotListDeduper.accepting(
            [SpotTestHelpers.makeSpot(id: "a"), SpotTestHelpers.makeSpot(id: "c")],
            into: &known
        )
        #expect(second.map(\.id) == ["c"])
        #expect(known == ["a", "b", "c"])
    }
}

struct FeedProfileContentPolicyTests {
    @Test func emptyWhenNilOrZeroCounts() {
        #expect(FeedProfileContentPolicy.hasContent(topVibes: 0, topCreators: 0, events30d: 0) == false)
        #expect(FeedProfileContentPolicy.hasContent(nil) == false)
    }

    @Test func hasContentWhenAnyBucketNonZero() {
        #expect(FeedProfileContentPolicy.hasContent(topVibes: 1, topCreators: 0, events30d: 0))
        #expect(FeedProfileContentPolicy.hasContent(topVibes: 0, topCreators: 2, events30d: 0))
        #expect(FeedProfileContentPolicy.hasContent(topVibes: 0, topCreators: 0, events30d: 3))
    }

    @Test func hasContentFromDecodedProfile() throws {
        let json = """
        {
          "version": 1,
          "top_vibes": [{"name":"Chill","score":1.0}],
          "top_creators": [],
          "event_summary_30d": {"total": 0, "window_days": 30}
        }
        """
        let data = try #require(json.data(using: .utf8))
        let profile = try JSONDecoder().decode(FeedProfile.self, from: data)
        #expect(FeedProfileContentPolicy.hasContent(profile))
    }
}

struct FeedProfileSnapshotParserTests {
    @Test func parsesRowPayload() throws {
        let json = """
        [{"profile_version":3,"last_computed_at":"2026-08-06T12:00:00Z","profile":{"version":1}}]
        """
        let data = try #require(json.data(using: .utf8))
        let snapshot = FeedProfileSnapshotParser.parse(data)
        #expect(snapshot.profileVersion == 3)
        #expect(snapshot.lastComputedAt != nil)
        #expect(snapshot.prettyJSON.contains("profile_version"))
    }

    @Test func fallsBackForNonArrayPayload() throws {
        let data = try #require(#"{"ok":true}"#.data(using: .utf8))
        let snapshot = FeedProfileSnapshotParser.parse(data)
        #expect(snapshot.profileVersion == nil)
        #expect(snapshot.prettyJSON.contains("ok"))
    }
}

struct CollectionNamePolicyTests {
    @Test func trimsAndGatesCreate() {
        #expect(CollectionNamePolicy.normalized("  Trips  ") == "Trips")
        #expect(CollectionNamePolicy.canCreate("  Trips  "))
        #expect(!CollectionNamePolicy.canCreate("   "))
    }
}

struct SettingsAccountChangeValidationTests {
    @Test func usernameAndPasswordGates() {
        #expect(SettingsAccountChangeValidation.usernameGate("  ") == .empty)
        #expect(SettingsAccountChangeValidation.usernameGate("ed") == .ok)

        #expect(
            SettingsAccountChangeValidation.passwordChangeGate(
                newPassword: "Abcdef1!",
                confirmPassword: "other",
                currentPassword: "x",
                requireCurrentPassword: true
            ) == .mismatch
        )
        #expect(
            SettingsAccountChangeValidation.passwordChangeGate(
                newPassword: "Abcdef1!",
                confirmPassword: "Abcdef1!",
                currentPassword: "",
                requireCurrentPassword: true
            ) == .currentPasswordRequired
        )
        #expect(
            SettingsAccountChangeValidation.requiresCurrentPassword(
                isEmailChange: true,
                isPasswordChange: false,
                currentPassword: ""
            )
        )
    }

    @Test func deleteAccountGates() {
        #expect(
            SettingsAccountChangeValidation.deleteAccountGate(
                confirmDelete: true,
                deletePassword: "secret",
                reauth: .password
            ) == .ok
        )
        #expect(
            SettingsAccountChangeValidation.deleteAccountGate(
                confirmDelete: false,
                deletePassword: "",
                reauth: .apple
            ) == .missingAppleConfirmation
        )
    }
}

struct PaywallPurchaseUIStateTests {
    @Test func busyAndDisabledFlags() {
        #expect(PaywallPurchaseUIState.isStoreBusy(isPurchasing: true, isRestoring: false))
        #expect(PaywallPurchaseUIState.isPurchaseDisabled(isStoreBusy: false, hasProduct: false))
        #expect(!PaywallPurchaseUIState.isPurchaseDisabled(isStoreBusy: false, hasProduct: true))
        #expect(PaywallPurchaseUIState.productLoadFailed(isLoadingProduct: false, hasProduct: false))
        #expect(!PaywallPurchaseUIState.productLoadFailed(isLoadingProduct: true, hasProduct: false))
    }

    @Test func titlesAndStatusCopy() {
        #expect(PaywallPurchaseUIState.primaryButtonTitle(isPurchasing: true, isRestoring: false, priceLine: "$4.99") == "Processing…")
        #expect(PaywallPurchaseUIState.primaryButtonTitle(isPurchasing: false, isRestoring: true, priceLine: "$4.99") == "Restoring…")
        #expect(PaywallPurchaseUIState.primaryButtonTitle(isPurchasing: false, isRestoring: false, priceLine: "") == "Subscribe to Spot Pro")
        #expect(
            PaywallPurchaseUIState.primaryButtonTitle(isPurchasing: false, isRestoring: false, priceLine: "$4.99")
                == "Subscribe to Spot Pro • $4.99"
        )
        #expect(PaywallPurchaseUIState.priceOrStatusLine(isLoadingProduct: true, priceLine: "") == "Loading subscription details…")
        let loadMessage = PaywallPurchaseUIState.productLoadMessage(productLoadFailed: true) ?? ""
        #expect(loadMessage.contains("Spot Pro"))
        #expect(PaywallPurchaseUIState.productLoadMessage(productLoadFailed: false) == nil)
    }
}
