//
//  SubscriptionPriceLineFormatter.swift
//  Spot
//
//  Created by Edward Wynman on 4/6/26.
//

import Foundation
import StoreKit

/// Builds paywall price strings from StoreKit `Product` (localized price + subscription period).
enum SubscriptionPriceLineFormatter {
    /// Builds a localized "price / period" line when the product is a subscription; otherwise returns `displayPrice` only.
    static func priceLine(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return product.displayPrice
        }
        return priceLine(
            displayPrice: product.displayPrice,
            subscriptionValue: period.value,
            subscriptionUnit: period.unit,
            locale: .current
        )
    }

    /// Assembles `displayPrice` and an optional subscription period (used by `priceLine(for:)` and tests).
    static func priceLine(
        displayPrice: String,
        subscriptionValue: Int?,
        subscriptionUnit: Product.SubscriptionPeriod.Unit?,
        locale: Locale = .current
    ) -> String {
        guard let value = subscriptionValue, let unit = subscriptionUnit else {
            return displayPrice
        }
        let suffix = localizedPeriodSuffix(value: value, unit: unit, locale: locale)
        guard !suffix.isEmpty else { return displayPrice }
        return "\(displayPrice) / \(suffix)"
    }

    /// Localized suffix from StoreKit period components (testable without constructing `Product.SubscriptionPeriod`).
    static func localizedPeriodSuffix(
        value: Int,
        unit: Product.SubscriptionPeriod.Unit,
        locale: Locale = .current
    ) -> String {
        guard value > 0 else { return "" }
        if value == 1 {
            switch unit {
            case .day:
                return "day"
            case .week:
                return "week"
            case .month:
                return "month"
            case .year:
                return "year"
            @unknown default:
                return ""
            }
        }

        switch unit {
        case .day:
            var components = DateComponents()
            components.day = value
            return dateComponentsFormatter(
                allowedUnits: .day,
                locale: locale
            ).string(from: components) ?? ""
        case .week:
            // `weekOfMonth` is the duration field used by `DateComponentsFormatter` for week-based periods.
            var components = DateComponents()
            components.weekOfMonth = value
            return dateComponentsFormatter(
                allowedUnits: .weekOfMonth,
                locale: locale
            ).string(from: components) ?? ""
        case .month:
            var components = DateComponents()
            components.month = value
            return dateComponentsFormatter(
                allowedUnits: .month,
                locale: locale
            ).string(from: components) ?? ""
        case .year:
            var components = DateComponents()
            components.year = value
            return dateComponentsFormatter(
                allowedUnits: .year,
                locale: locale
            ).string(from: components) ?? ""
        @unknown default:
            return ""
        }
    }

    private static func dateComponentsFormatter(allowedUnits: NSCalendar.Unit, locale: Locale) -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropAll
        formatter.allowedUnits = allowedUnits
        return formatter
    }
}
