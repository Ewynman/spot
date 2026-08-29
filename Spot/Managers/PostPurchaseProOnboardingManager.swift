//
//  PostPurchaseProOnboardingManager.swift
//  Spot
//
//  Created by Edward Wynman on 4/6/26.
//

import SwiftUI
import UIKit

@MainActor
final class PostPurchaseProOnboardingManager: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case fivePhotos
        case customVibes
        case editSpots
        case bookmarks
        case collections
        case searchFilters
        case supporterBadge
        case finale
    }

    @Published var step: Step = .welcome
    /// 0 = highlight new-collection tile; 1 = "New collection" sheet mock
    @Published var collectionsSubstep: Int = 0

    static func shouldShow(userId: String?) -> Bool {
        guard let userId, !userId.isEmpty else { return false }
        return !UserDefaults.standard.bool(forKey: storageKey(for: userId))
    }

    static func markSeen(userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        UserDefaults.standard.set(true, forKey: storageKey(for: userId))
    }

    private static func storageKey(for userId: String) -> String {
        "hasSeenPostPurchaseProOnboarding.\(userId)"
    }

    var progress: CGFloat {
        CGFloat(step.rawValue) / CGFloat(Step.finale.rawValue)
    }

    var isOnWelcome: Bool { step == .welcome }
    var isFinale: Bool { step == .finale }

    func next() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if step == .collections, collectionsSubstep == 0 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                collectionsSubstep = 1
            }
            return
        }
        guard let idx = Step.allCases.firstIndex(of: step), idx + 1 < Step.allCases.count else { return }
        withAnimation(.easeOut(duration: 0.28)) {
            step = Step.allCases[idx + 1]
            if step == .collections { collectionsSubstep = 0 }
        }
    }

    func goBack() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if step == .collections, collectionsSubstep == 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                collectionsSubstep = 0
            }
            return
        }
        guard let idx = Step.allCases.firstIndex(of: step), idx > 0 else { return }
        withAnimation(.easeOut(duration: 0.28)) {
            step = Step.allCases[idx - 1]
            if step == .collections { collectionsSubstep = 0 }
        }
    }

    func skipEntireTour(userId: String?) {
        Self.markSeen(userId: userId)
    }
}
