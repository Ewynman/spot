//
//  HomeTourHost.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct HomeTourHost<Content: View>: View {
    @ObservedObject var manager: HomeTourManager
    @Binding var coachFrames: [CoachTarget: CGRect]
    let isFirstSessionAfterSignup: Bool
    let content: Content

    init(manager: HomeTourManager, coachFrames: Binding<[CoachTarget: CGRect]>, isFirstSessionAfterSignup: Bool, @ViewBuilder content: () -> Content) {
        self.manager = manager
        self._coachFrames = coachFrames
        self.isFirstSessionAfterSignup = isFirstSessionAfterSignup
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .onAppear { manager.startIfNeeded(isFirstSessionAfterSignup: isFirstSessionAfterSignup) }
                .onPreferenceChange(CoachFramesPrefKey.self) { coachFrames = $0 }
        }
        .sheet(isPresented: $manager.isWelcomePresented) {
            WelcomeTourSheet(onStart: manager.startCoach, onSkip: manager.skip)
        }
        .overlay(coachOverlay)
    }

    @ViewBuilder
    private var coachOverlay: some View {
        if manager.isCoachPresented {
            CoachDemoOverlay(
                step: manager.currentStep,
                title: title(for: manager.currentStep),
                subtitle: subtitle(for: manager.currentStep),
                isLast: manager.currentStep == .likeSave,
                onNext: manager.next,
                onSkip: manager.skip
            )
            .accessibilityAddTraits(.isModal)
        }
    }

    private func targetRect(for step: HomeTourManager.Step) -> CGRect? {
        switch step {
        case .username: return coachFrames[.username]
        case .location: return coachFrames[.location]
        case .vibe: return coachFrames[.vibeTag]
        case .likeSave: return coachFrames[.likeSave]
        }
    }
    private func title(for step: HomeTourManager.Step) -> String {
        switch step {
        case .username: return "Profile"
        case .location: return "Location"
        case .vibe: return "Vibe Tag"
        case .likeSave: return "Like & Save"
        }
    }
    private func subtitle(for step: HomeTourManager.Step) -> String {
        switch step {
        case .username: return "This is the Spot creator’s username."
        case .location: return "Where this Spot is."
        case .vibe: return "Quick feel for the place."
        case .likeSave: return "Tap to like or bookmark a Spot."
        }
    }
}

#Preview {
    let manager = HomeTourManager()
    return HomeTourHost(manager: manager, coachFrames: .constant([:]), isFirstSessionAfterSignup: true) {
        VStack { Text("Home content") }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "F5F3EF"))
    }
}

private struct WelcomeTourSheet: View {
    let onStart: () -> Void
    let onSkip: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to Spot")
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.buttonText)
            Text("A Spot is a place with a vibe. Share one photo, add a vibe tag, and help others discover great places.")
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.buttonText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.primary, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: onStart) {
                    Text("Start Tour")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Constants.Colors.primary)
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}
