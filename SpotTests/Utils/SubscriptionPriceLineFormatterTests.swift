//
// Created By: Wynman, Edward
// Date: 04/06/2026
//

import Foundation
import StoreKit
import Testing
@testable import Spot

struct SubscriptionPriceLineFormatterTests {

    private let fixedLocale = Locale(identifier: "en_US")

    @Test func localizedPeriodSuffixYear() {
        let s = SubscriptionPriceLineFormatter.localizedPeriodSuffix(value: 1, unit: .year, locale: fixedLocale)
        #expect(s == "year")
    }

    @Test func localizedPeriodSuffixMonth() {
        let s = SubscriptionPriceLineFormatter.localizedPeriodSuffix(value: 1, unit: .month, locale: fixedLocale)
        #expect(s == "month")
    }

    @Test func localizedPeriodSuffixWeek() {
        let s = SubscriptionPriceLineFormatter.localizedPeriodSuffix(value: 2, unit: .week, locale: fixedLocale)
        #expect(!s.isEmpty)
        #expect(s.contains("2"))
    }

    @Test func localizedPeriodSuffixDay() {
        let s = SubscriptionPriceLineFormatter.localizedPeriodSuffix(value: 3, unit: .day, locale: fixedLocale)
        #expect(!s.isEmpty)
        #expect(s.contains("3"))
    }

    @Test func localizedPeriodSuffixZeroValueReturnsEmpty() {
        #expect(SubscriptionPriceLineFormatter.localizedPeriodSuffix(value: 0, unit: .year, locale: fixedLocale).isEmpty)
    }

    @Test func priceLineWithoutPeriodReturnsDisplayPriceOnly() {
        let line = SubscriptionPriceLineFormatter.priceLine(
            displayPrice: "$4.99",
            subscriptionValue: nil,
            subscriptionUnit: nil,
            locale: fixedLocale
        )
        #expect(line == "$4.99")
    }

    @Test func priceLineCombinesDisplayPriceAndLocalizedYear() {
        let line = SubscriptionPriceLineFormatter.priceLine(
            displayPrice: "$9.99",
            subscriptionValue: 1,
            subscriptionUnit: .year,
            locale: fixedLocale
        )
        #expect(line == "$9.99 / year")
    }

    @Test func mockedUSYearlyProductRendersTargetPrice() {
        let line = SubscriptionPriceLineFormatter.priceLine(
            displayPrice: "$19.99",
            subscriptionValue: 1,
            subscriptionUnit: .year,
            locale: fixedLocale
        )
        #expect(line == "$19.99 / year")
    }

    @Test func priceLineFallsBackToDisplayPriceWhenSuffixEmpty() {
        let line = SubscriptionPriceLineFormatter.priceLine(
            displayPrice: "$9.99",
            subscriptionValue: 0,
            subscriptionUnit: .year,
            locale: fixedLocale
        )
        #expect(line == "$9.99")
    }
}
