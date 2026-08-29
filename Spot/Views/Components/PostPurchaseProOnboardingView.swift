//
//  PostPurchaseProOnboardingView.swift
//  Spot
//
//  Created by Edward Wynman on 4/6/26.
//

import SwiftUI

/// Full-screen guided tour after the user becomes Pro (in-app purchase or restore).
struct PostPurchaseProOnboardingView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var tour = PostPurchaseProOnboardingManager()

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if !tour.isOnWelcome {
                    headerBar
                }

                progressBar

                Group {
                    if tour.isOnWelcome {
                        welcomeContent
                    } else if tour.isFinale {
                        finaleContent
                    } else {
                        featureStepContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button(action: { tour.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
                    .padding(10)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Back")

            Spacer()

            Button(action: skip) {
                Text("Skip")
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Constants.Colors.primary.opacity(0.12))
                    .frame(height: 4)
                Capsule()
                    .fill(Constants.Colors.primary)
                    .frame(width: max(8, geo.size.width * tour.progress), height: 4)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 20)
        .padding(.top, tour.isOnWelcome ? 24 : 12)
        .padding(.bottom, 8)
        .animation(.easeOut(duration: 0.25), value: tour.step)
    }

    private var welcomeContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "star.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Constants.Colors.primary)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text("You're on Pro")
                .font(FontManager.sectionHeader())
                .fontWeight(.bold)
                .foregroundColor(Constants.Colors.primary)
                .multilineTextAlignment(.center)

            Text("Here’s a quick tour of what’s new. About a minute — tap through when you’re ready.")
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Button(action: { tour.next() }) {
                    Text("Show me what’s new")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Constants.Colors.primary)
                        .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: skip) {
                    Text("Skip for now")
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private var featureStepContent: some View {
        VStack(spacing: 20) {
            mockCanvas
                .padding(.horizontal, 20)
                .frame(maxHeight: 360)

            VStack(spacing: 10) {
                Text(featureTitle)
                    .font(FontManager.sectionHeader())
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.primary)
                    .multilineTextAlignment(.center)

                Text(featureSubtitle)
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let hint = featureActionHint {
                    Text(hint)
                        .font(FontManager.primaryText())
                        .fontWeight(.medium)
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)

            Button(action: { tour.next() }) {
                Text("Next")
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.Colors.primary)
                    .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var finaleContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("That’s Pro")
                .font(FontManager.sectionHeader())
                .fontWeight(.bold)
                .foregroundColor(Constants.Colors.primary)

            Text("More photos, your own vibes, edits when you need them, saves without limits, collections, sharper search — and thanks for supporting Spot.")
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Text("More photos · Custom vibes · Edits · Saves · Collections · Filters · Supporter badge")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Constants.Colors.primary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button(action: complete) {
                Text("Explore the app")
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.Colors.primary)
                    .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    @ViewBuilder
    private var mockCanvas: some View {
        switch tour.step {
        case .fivePhotos:
            MockFivePhotoStrip()
        case .customVibes:
            MockCustomVibeChips()
        case .editSpots:
            MockEditSpotCard()
        case .bookmarks:
            MockBookmarkHighlight()
        case .collections:
            MockCollectionsFlow(substep: tour.collectionsSubstep)
        case .searchFilters:
            MockSearchFilters()
        case .supporterBadge:
            MockSupporterProfile()
        default:
            EmptyView()
        }
    }

    private var featureTitle: String {
        switch tour.step {
        case .fivePhotos: return "Five photos, one story"
        case .customVibes: return "Your vibes, your rules"
        case .editSpots: return "Edit after you post"
        case .bookmarks: return "Save everything you love"
        case .collections: return tour.collectionsSubstep == 0 ? "Turn saves into albums" : "Name it, you’re done"
        case .searchFilters: return "Search with intent"
        case .supporterBadge: return "You’re a Spot supporter"
        default: return ""
        }
    }

    private var featureSubtitle: String {
        switch tour.step {
        case .fivePhotos:
            return "Pro lets you add up to five images so one spot can carry the full moment."
        case .customVibes:
            return "Add custom vibe tags so posts sound like you — not just a preset list."
        case .editSpots:
            return "Tweak a caption or swap a photo; your spot updates for everyone."
        case .bookmarks:
            return "No caps. Bookmark spots you want to revisit and build your own map."
        case .collections:
            return tour.collectionsSubstep == 0
                ? "Group bookmarks into collections — date nights, weekend trips, want-to-try."
                : "Give the collection a name, tap Create, and you’re organized."
        case .searchFilters:
            return "Use advanced filters to cut through noise and find places faster."
        case .supporterBadge:
            return "A subtle badge on your profile shows you help keep Spot going."
        default:
            return ""
        }
    }

    private var featureActionHint: String? {
        switch tour.step {
        case .collections where tour.collectionsSubstep == 0:
            return "→ Create your first collection"
        default:
            return nil
        }
    }

    private func skip() {
        tour.skipEntireTour(userId: authVM.userId)
        onFinished()
    }

    private func complete() {
        PostPurchaseProOnboardingManager.markSeen(userId: authVM.userId)
        onFinished()
    }
}

// MARK: - Visual mocks

private struct MockFivePhotoStrip: View {
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New spot")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.primary.opacity(0.5))
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(i < 4 ? Color.gray.opacity(0.2) : Constants.Colors.primary.opacity(0.15))
                        .frame(width: 54, height: 54)
                        .overlay {
                            if i == 4 {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Constants.Colors.primary)
                                    .scaleEffect(pulse ? 1.08 : 1.0)
                                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                            }
                        }
                        .overlay {
                            if i == 4 {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Constants.Colors.primary, lineWidth: 2)
                            }
                        }
                }
            }
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(i == 4 ? Constants.Colors.primary : Color.gray.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.primary.opacity(0.2), lineWidth: 1))
        .onAppear { pulse = true }
    }
}

private struct MockCustomVibeChips: View {
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Vibe tags")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.primary.opacity(0.5))
            FlowChipsRow()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.primary.opacity(0.2), lineWidth: 1))
        .onAppear { pulse = true }
    }

    private func FlowChipsRow() -> some View {
        HStack(spacing: 8) {
            chip("Cozy", highlight: false)
            chip("Sunset", highlight: false)
            chip("Custom", highlight: true)
            Spacer(minLength: 0)
        }
    }

    private func chip(_ text: String, highlight: Bool) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(highlight ? Constants.Colors.buttonText : Constants.Colors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(highlight ? Constants.Colors.primary : Color.gray.opacity(0.12))
            .cornerRadius(20)
            .overlay {
                if highlight {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Constants.Colors.primary, lineWidth: 2)
                        .scaleEffect(pulse ? 1.04 : 1.0)
                        .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: pulse)
                }
            }
    }
}

private struct MockEditSpotCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle().fill(Constants.Colors.primary.opacity(0.3)).frame(width: 28, height: 28)
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(width: 100, height: 12)
                Spacer()
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundColor(Constants.Colors.primary)
            }
            .padding(12)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 140)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Edit")
                        .font(FontManager.primaryText())
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Constants.Colors.primary.opacity(0.12))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 2))
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.primary.opacity(0.2), lineWidth: 1))
    }
}

private struct MockBookmarkHighlight: View {
    @State private var filled = false

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.12))
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(width: 140, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(width: 100, height: 10)
            }
            Spacer()
            Image(systemName: filled ? "bookmark.fill" : "bookmark")
                .font(.system(size: 28))
                .foregroundColor(Constants.Colors.primary)
                .scaleEffect(filled ? 1.12 : 1.0)
                .animation(.spring(response: 0.45, dampingFraction: 0.65), value: filled)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.primary.opacity(0.2), lineWidth: 1))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                filled = true
            }
        }
    }
}

private struct MockCollectionsFlow: View {
    let substep: Int
    @State private var plusPulse = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .stroke(Constants.Colors.primary, lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                        .overlay(Text("Done").font(.caption2).fontWeight(.semibold).foregroundColor(Constants.Colors.primary))
                    Spacer()
                    Text("Add to Collection")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Constants.Colors.primary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 8)

                ForEach([("Europe", true), ("Coffee runs", false)], id: \.0) { name, selected in
                    HStack {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        Text(name).fontWeight(.semibold)
                        Spacer()
                        Text(selected ? "8 spots" : "12 spots")
                            .font(.caption2)
                    }
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.primary)
                    .padding(12)
                    .background(selected ? Constants.Colors.accent : Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary.opacity(0.2), lineWidth: 1))
                }

                HStack {
                    Image(systemName: "plus")
                    Text("New collection").fontWeight(.semibold)
                    Spacer()
                }
                .font(.subheadline)
                .foregroundColor(Constants.Colors.primary)
                .padding(12)
                .background(Constants.Colors.accent.opacity(0.6))
                .cornerRadius(12)
                .scaleEffect(substep == 0 && plusPulse ? 1.03 : 1.0)
                .animation(substep == 0 ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true) : .default, value: plusPulse)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Constants.Colors.primary.opacity(0.15), lineWidth: 1))

            if substep == 1 {
                VStack(spacing: 12) {
                    Capsule().fill(Color.gray.opacity(0.35)).frame(width: 36, height: 4).padding(.top, 8)
                    Text("New Collection")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    HStack(spacing: 8) {
                        TextField("", text: .constant("Coffee runs"))
                            .font(.body)
                            .padding(12)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 2))
                        Text("Create")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Constants.Colors.buttonText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Constants.Colors.primary.opacity(0.85))
                            .cornerRadius(12)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            plusPulse = true
        }
    }
}

private struct MockSearchFilters: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                Text("Find a spot…")
                    .font(.body)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(12)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(14)

            HStack(spacing: 8) {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.buttonText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Constants.Colors.primary)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Constants.Colors.primary, lineWidth: 2))
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.primary.opacity(0.2), lineWidth: 1))
    }
}

private struct MockSupporterProfile: View {
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Constants.Colors.primary.opacity(0.25))
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Your name")
                        .font(.headline)
                        .foregroundColor(Constants.Colors.primary)
                    Text("Supporter")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Constants.Colors.buttonText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Constants.Colors.primary)
                        .cornerRadius(8)
                        .opacity(shimmer ? 1 : 0.85)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: shimmer)
                }
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(width: 160, height: 10)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.primary.opacity(0.2), lineWidth: 1))
        .onAppear { shimmer = true }
    }
}

#Preview {
    PostPurchaseProOnboardingView(onFinished: {})
        .environmentObject(AuthViewModel())
}
