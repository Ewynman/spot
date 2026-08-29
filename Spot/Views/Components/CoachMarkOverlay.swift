//
//  CoachMarkOverlay.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct CoachMarkOverlay: View {
    let targetRect: CGRect?
    let title: String
    let subtitle: String
    let isLast: Bool
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var animate: Bool = false

    var body: some View {
        ZStack {
            // Dim layer with cutout using destinationOut
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                if let rect = targetRect {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .blendMode(.destinationOut)
                        .animation(.easeInOut(duration: 0.25), value: targetRect)
                }
            }
            .compositingGroup()
            .accessibilityHidden(true)

            // Content
            VStack(spacing: 12) {
                Text(title)
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.buttonText)
                Text(subtitle)
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                HStack(spacing: 16) {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: onNext) {
                        Text(isLast ? "Done" : "Next")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Constants.Colors.primary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 140)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityElement(children: .contain)
    }
}

// Demo overlay that draws its own fake card and highlights the requested element
struct CoachDemoOverlay: View {
    let step: HomeTourManager.Step
    let title: String
    let subtitle: String
    let isLast: Bool
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            // Fake card (white body only)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle().fill(Constants.Colors.primary).frame(width: 28, height: 28)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(step == .username ? Constants.Colors.primary : Color.gray.opacity(0.3))
                            .frame(width: 120, height: 14)
                        Spacer()
                        RoundedRectangle(cornerRadius: 6)
                            .fill(step == .location ? Constants.Colors.primary : Color.gray.opacity(0.3))
                            .frame(width: 140, height: 14)
                    }
                    .padding(.horizontal, 16)

                    // Placeholder image
                    Image("tour_placeholder")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(12)

                    HStack {
                        // Like / Save placeholders
                        HStack(spacing: 16) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(step == .likeSave ? Constants.Colors.primary : Color.gray.opacity(0.3))
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(step == .likeSave ? Constants.Colors.primary : Color.gray.opacity(0.3))
                        }
                        Spacer()
                        RoundedRectangle(cornerRadius: 12)
                            .fill(step == .vibe ? Constants.Colors.primary : Color.gray.opacity(0.3))
                            .frame(width: 84, height: 24)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Text(title)
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.buttonText)
                Text(subtitle)
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                HStack(spacing: 16) {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: onNext) {
                        Text(isLast ? "Done" : "Next")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Constants.Colors.primary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 140)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

        }
    }

    // No-op retained for compatibility if needed
    private func highlight(_ target: HomeTourManager.Step) -> Color { step == target ? Constants.Colors.primary : Color.gray.opacity(0.3) }
}

#Preview {
    CoachMarkOverlay(
        targetRect: CGRect(x: 100, y: 200, width: 160, height: 120),
        title: "Welcome",
        subtitle: "Tap next to continue the tour.",
        isLast: false,
        onNext: {},
        onSkip: {}
    )
}

struct SpotFirstRunOnboardingOverlay: View {
    @ObservedObject var manager: SpotFirstRunOnboardingManager
    let targetRect: CGRect?
    let onPrimary: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if manager.isPresented {
            ZStack {
                if manager.prefersFullScreenCard {
                    fullScreenStep
                } else {
                    guidedStep
                }
            }
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: reduceMotion ? 0.01 : 0.22), value: manager.currentStep)
            .accessibilityAddTraits(.isModal)
        }
    }

    private var fullScreenStep: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 22)

                Spacer()

                VStack(spacing: 22) {
                    Image(systemName: manager.currentStep == .welcome ? "sparkles" : "checkmark.circle.fill")
                        .font(.system(size: 62, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text(manager.currentStep.title)
                            .font(FontManager.sectionHeader())
                            .fontWeight(.bold)
                            .foregroundColor(Constants.Colors.primary)
                            .multilineTextAlignment(.center)

                        Text(manager.currentStep.body)
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onPrimary) {
                        Text(manager.currentStep == .welcome ? "Start exploring" : "Start exploring")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Constants.Colors.primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(manager.currentStep == .welcome ? "Start exploring" : "Finish onboarding")

                    if manager.currentStep == .welcome {
                        Button(action: onSkip) {
                            Text("Skip")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Skip onboarding")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private var guidedStep: some View {
        ZStack {
            if blocksUnderlyingFeedWhileAwaitingSpotTarget {
                Constants.Colors.background
                    .ignoresSafeArea()
            }
            spotlightScrim
                .allowsHitTesting(manager.currentStep != .mapTab)
            if shouldShowFallbackSpot {
                fallbackSpotCard
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            if shouldShowPulse {
                pulseRing
            }
            instructionCard
                .padding(.horizontal, 16)
                .padding(.bottom, instructionBottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
    }

    private var fallbackSpotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Constants.Colors.accent)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Constants.Colors.primary)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("maya")
                        .font(FontManager.primaryText())
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                    Text("saved a favorite place")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Constants.Colors.primary.opacity(0.58))
                }

                Spacer()

                Text("Brooklyn, NY")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary.opacity(0.72))
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Constants.Colors.accent,
                            Constants.Colors.background
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 170)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sunday coffee walk")
                            .font(.system(size: 18, weight: .bold))
                        Text("Quiet, cozy, worth saving.")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Constants.Colors.primary)
                    .padding(16)
                }

            HStack {
                HStack(spacing: 16) {
                    Image(systemName: "heart")
                    Image(systemName: "bookmark")
                }
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Constants.Colors.primary.opacity(0.72))

                Spacer()

                Text("Cozy Corner")
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Constants.Colors.accent)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Constants.Colors.background)
                .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 10)
        )
        .accessibilityLabel("Example Spot card")
    }

    private var spotlightScrim: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()

            if let rect = paddedTargetRect {
                RoundedRectangle(cornerRadius: cornerRadius(for: manager.currentStep), style: .continuous)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .overlay {
            if let rect = paddedTargetRect {
                RoundedRectangle(cornerRadius: cornerRadius(for: manager.currentStep), style: .continuous)
                    .stroke(Constants.Colors.accent.opacity(0.95), lineWidth: manager.currentStep == .vibeTag ? 3 : 2)
                    .shadow(color: Constants.Colors.accent.opacity(manager.currentStep == .vibeTag ? 0.8 : 0.35), radius: 12)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .accessibilityHidden(true)
    }

    private var instructionCard: some View {
        VStack(spacing: 14) {
            HStack {
                if manager.canGoBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Constants.Colors.primary)
                            .padding(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Back")
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }

                Spacer()

                Text("\(manager.currentStep.rawValue) of \(SpotFirstRunOnboardingManager.Step.allCases.count - 1)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary.opacity(0.7))

                Spacer()

                Button(action: onSkip) {
                    Text("Skip")
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Skip onboarding")
            }

            progressBar

            VStack(spacing: 8) {
                Text(manager.currentStep.title)
                    .font(FontManager.sectionHeader())
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.primary)
                    .multilineTextAlignment(.center)

                Text(bodyText)
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.Colors.primary)
                    .cornerRadius(18)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(primaryTitle)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Constants.Colors.background)
                .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 10)
        )
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Constants.Colors.primary.opacity(0.12))
                Capsule()
                    .fill(Constants.Colors.primary)
                    .frame(width: max(8, geo.size.width * manager.progress))
            }
        }
        .frame(height: 4)
    }

    private var pulseRing: some View {
        Group {
            if let rect = paddedTargetRect {
                RoundedRectangle(cornerRadius: cornerRadius(for: manager.currentStep), style: .continuous)
                    .stroke(Constants.Colors.accent.opacity(0.55), lineWidth: 8)
                    .frame(width: rect.width + 8, height: rect.height + 8)
                    .position(x: rect.midX, y: rect.midY)
                    .opacity(reduceMotion ? 0.4 : 0.75)
            }
        }
        .accessibilityHidden(true)
    }

    private var paddedTargetRect: CGRect? {
        guard let targetRect, !targetRect.isEmpty else { return nil }
        return targetRect.insetBy(dx: -8, dy: -8)
    }

    private var shouldShowPulse: Bool {
        manager.currentStep == .vibeTag || manager.currentStep == .bookmark
    }

    private var shouldShowFallbackSpot: Bool {
        guard targetRect == nil else { return false }
        switch manager.currentStep {
        case .spotCard, .spotDetails, .vibeTag, .like, .bookmark, .mapFlip, .creator:
            return true
        default:
            return false
        }
    }

    /// Hides the home feed skeleton/loading UI until a real `SpotCard` reports a coach frame.
    private var blocksUnderlyingFeedWhileAwaitingSpotTarget: Bool {
        manager.currentStep == .spotCard && targetRect == nil
    }

    private var instructionBottomPadding: CGFloat {
        manager.currentStep == .mapTab ? 110 : 20
    }

    private var bodyText: String {
        if targetRect == nil, let fallback = manager.currentStep.fallbackBody {
            return fallback
        }
        return manager.currentStep.body
    }

    private var primaryTitle: String {
        switch manager.currentStep {
        case .mapTab:
            return "Tap Map to continue"
        case .userLocation:
            return "Continue"
        case .markerPreview:
            return "Finish tour"
        default:
            return "Next"
        }
    }

    private func cornerRadius(for step: SpotFirstRunOnboardingManager.Step) -> CGFloat {
        switch step {
        case .like, .bookmark, .mapFlip, .mapTab, .userLocation, .mapMarkers:
            return 22
        case .vibeTag:
            return 18
        default:
            return 20
        }
    }
}
