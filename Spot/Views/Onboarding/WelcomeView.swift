//
//  WelcomeView.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//

import SwiftUI

struct WelcomeHeroMotionConfiguration: Equatable {
    let oneTimeEntranceEnabled: Bool
    let continuousAnimationsEnabled: Bool
    let pinPulseEnabled: Bool

    static func resolved(reduceMotionEnabled: Bool) -> WelcomeHeroMotionConfiguration {
        WelcomeHeroMotionConfiguration(
            oneTimeEntranceEnabled: true,
            continuousAnimationsEnabled: !reduceMotionEnabled,
            pinPulseEnabled: !reduceMotionEnabled
        )
    }
}

struct OrbitingItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case tag(text: String, icon: String)
        case avatar(initials: String, palette: Int)
        case pin(isHighlighted: Bool)
        case card(title: String, subtitle: String, meta: String)
    }

    let id: String
    let kind: Kind
    let orbitRadiusXMultiplier: CGFloat
    let orbitRadiusYMultiplier: CGFloat
    let phaseOffset: Double
    let size: CGSize
}

enum WelcomeHeroContent {
    static let orbitingItems: [OrbitingItem] = [
        OrbitingItem(
            id: "tag-scenic",
            kind: .tag(text: tag(named: "Scenic View"), icon: systemImage(for: "Scenic View")),
            orbitRadiusXMultiplier: 1.00,
            orbitRadiusYMultiplier: 0.84,
            phaseOffset: -2.40,
            size: CGSize(width: 116, height: 36)
        ),
        OrbitingItem(
            id: "tag-foodie",
            kind: .tag(text: tag(named: "Foodie Heaven"), icon: systemImage(for: "Foodie Heaven")),
            orbitRadiusXMultiplier: 1.08,
            orbitRadiusYMultiplier: 0.90,
            phaseOffset: -0.45,
            size: CGSize(width: 132, height: 36)
        ),
        OrbitingItem(
            id: "tag-quiet",
            kind: .tag(text: tag(named: "Quiet Moment"), icon: systemImage(for: "Quiet Moment")),
            orbitRadiusXMultiplier: 1.02,
            orbitRadiusYMultiplier: 0.95,
            phaseOffset: 1.28,
            size: CGSize(width: 128, height: 36)
        ),
        OrbitingItem(
            id: "avatar-noah",
            kind: .avatar(initials: "N", palette: 0),
            orbitRadiusXMultiplier: 0.86,
            orbitRadiusYMultiplier: 0.78,
            phaseOffset: -1.25,
            size: CGSize(width: 42, height: 42)
        ),
        OrbitingItem(
            id: "avatar-jules",
            kind: .avatar(initials: "J", palette: 1),
            orbitRadiusXMultiplier: 0.92,
            orbitRadiusYMultiplier: 0.80,
            phaseOffset: 2.68,
            size: CGSize(width: 42, height: 42)
        ),
        OrbitingItem(
            id: "pin-primary",
            kind: .pin(isHighlighted: true),
            orbitRadiusXMultiplier: 0.72,
            orbitRadiusYMultiplier: 0.66,
            phaseOffset: 0.48,
            size: CGSize(width: 48, height: 48)
        ),
        OrbitingItem(
            id: "pin-secondary",
            kind: .pin(isHighlighted: false),
            orbitRadiusXMultiplier: 0.74,
            orbitRadiusYMultiplier: 0.70,
            phaseOffset: -3.05,
            size: CGSize(width: 34, height: 34)
        ),
        OrbitingItem(
            id: "card-romantic",
            kind: .card(
                title: tag(named: "Romantic"),
                subtitle: "Saved by Noah",
                meta: "\(tag(named: "Beach Day")) · \(tag(named: "Cozy Corner")) · 2.1 mi"
            ),
            orbitRadiusXMultiplier: 0.82,
            orbitRadiusYMultiplier: 1.02,
            phaseOffset: 1.92,
            size: CGSize(width: 210, height: 86)
        )
    ]

    static func tag(named fallback: String) -> String {
        Constants.VibeTags.defaultTags.first { $0.caseInsensitiveCompare(fallback) == .orderedSame } ?? fallback
    }

    static func systemImage(for title: String) -> String {
        let normalized = title.lowercased()

        if normalized.contains("coffee") || normalized.contains("foodie") || normalized.contains("brunch") {
            return "cup.and.saucer.fill"
        } else if normalized.contains("hidden") || normalized.contains("photo") {
            return "sparkles"
        } else if normalized.contains("romantic") || normalized.contains("date") {
            return "heart.fill"
        } else if normalized.contains("beach") || normalized.contains("waterfront") {
            return "water.waves"
        } else if normalized.contains("nature") || normalized.contains("pet") {
            return "leaf.fill"
        } else if normalized.contains("late") {
            return "moon.stars.fill"
        } else if normalized.contains("study") || normalized.contains("historical") {
            return "book.fill"
        } else if normalized.contains("scenic") || normalized.contains("adventure") {
            return "mountain.2.fill"
        } else if normalized.contains("family") || normalized.contains("people") {
            return "person.2.fill"
        }

        return "mappin.and.ellipse"
    }
}

struct WelcomeHeroSpin {
    static let ringSpinSpeed = (2 * Double.pi) / 32.0
    static let globeSpinCycleDuration: TimeInterval = 24.0

    struct Metrics: Equatable {
        let theta: Double
        let position: CGPoint
        let scale: Double
        let opacity: Double
        let zIndex: Double
    }

    static func position(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * radiusX,
            y: center.y + sin(angle) * radiusY
        )
    }

    static func metrics(
        for item: OrbitingItem,
        center: CGPoint,
        baseRadiusX: CGFloat,
        baseRadiusY: CGFloat,
        elapsedTime: TimeInterval,
        ringSpinSpeed: Double = WelcomeHeroSpin.ringSpinSpeed
    ) -> Metrics {
        let theta = elapsedTime * ringSpinSpeed + item.phaseOffset
        let position = position(
            center: center,
            radiusX: baseRadiusX * item.orbitRadiusXMultiplier,
            radiusY: baseRadiusY * item.orbitRadiusYMultiplier,
            angle: CGFloat(theta)
        )

        return Metrics(
            theta: theta,
            position: position,
            scale: 1,
            opacity: 1,
            zIndex: 10
        )
    }
}

struct WelcomeView: View {
    private enum AuthDestination {
        case signup
        case login
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var termsStore = PreAuthTermsAgreementStore.shared
    @State private var navigateToSignup = false
    @State private var navigateToLogin = false
    @State private var authDestination: AuthDestination = .signup
    @State private var appleErrorMessage: String?
    @State private var headerVisible = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    SpotWelcomeBackgroundView()

                    VStack(spacing: 0) {
                        SpotWelcomeHeaderView(isVisible: headerVisible, reduceMotion: reduceMotion)
                            .padding(.top, proxy.safeAreaInsets.top + topPadding(for: proxy.size))
                            .padding(.horizontal, 28)

                        Spacer(minLength: 10)

                        SpotWelcomeHeroView(configuration: .resolved(reduceMotionEnabled: reduceMotion))
                            .frame(height: heroHeight(for: proxy.size))
                            .padding(.horizontal, 18)
                            .layoutPriority(1)

                        Spacer(minLength: 10)

                        WelcomeAuthActionsView(
                            appleErrorMessage: appleErrorMessage,
                            isTermsAccepted: termsStore.hasAgreed,
                            termsURL: termsStore.termsURL,
                            privacyURL: termsStore.privacyURL,
                            termsAgreementBinding: Binding(
                                get: { termsStore.hasAgreed },
                                set: { termsStore.setAgreed($0) }
                            ),
                            onAppleRequest: {
                                appleErrorMessage = nil
                                SpotLogger.log(WelcomeViewLogs.appleSignInTapped)
                            },
                            onAppleSuccess: {
                                SpotLogger.log(WelcomeViewLogs.appleSignInSucceeded)
                                // Root auth gate will transition automatically from auth state.
                            },
                            onAppleError: { message in
                                appleErrorMessage = message
                                SpotLogger.log(WelcomeViewLogs.appleSignInFailed, details: ["error": message])
                            },
                            onGetStarted: {
                                appleErrorMessage = nil
                                guard termsStore.hasAgreed else {
                                    termsStore.logGated(action: "get_started")
                                    appleErrorMessage = "Please agree to Spot's Terms of Use and Privacy Policy to continue."
                                    return
                                }
                                SpotLogger.log(WelcomeViewLogs.getStartedTapped)
                                startOnboardingFlow(destination: .signup)
                            },
                            onLogin: {
                                appleErrorMessage = nil
                                guard termsStore.hasAgreed else {
                                    termsStore.logGated(action: "log_in")
                                    appleErrorMessage = "Please agree to Spot's Terms of Use and Privacy Policy to continue."
                                    return
                                }
                                SpotLogger.log(WelcomeViewLogs.loginTapped)
                                navigateToLogin = true
                            }
                        )
                        .padding(.horizontal, 26)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, 28))
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .navigationDestination(isPresented: $navigateToSignup) {
                SignupView()
            }
            .navigationDestination(isPresented: $navigateToLogin) {
                LoginView()
            }
            .navigationBarBackButtonHidden(true)
            .accessibilityIdentifier("welcome.screen")
            .onAppear {
                SpotLogger.log(WelcomeViewLogs.screenViewed)
                if reduceMotion {
                    headerVisible = true
                } else {
                    withAnimation(.easeOut(duration: 0.55)) {
                        headerVisible = true
                    }
                }
                Task { await termsStore.loadActiveVersion() }
            }
        }
    }

    private func topPadding(for size: CGSize) -> CGFloat {
        size.height < 700 ? 18 : 28
    }

    private func heroHeight(for size: CGSize) -> CGFloat {
        let proposed = size.height * (size.height < 700 ? 0.29 : 0.33)
        return min(max(proposed, 210), 290)
    }

    private func startOnboardingFlow(destination: AuthDestination) {
        // Apple App Review (Guidelines 5.1.1 / 5.1.5 / 4.5.4): permissions
        // must NOT be asked as a coercive pre-auth gauntlet. We jump straight
        // to the chosen auth flow. Each permission is later requested only
        // when the user taps the related feature for the first time.
        authDestination = destination
        permissionManager.updatePermissionStatuses()
        routeToDestination(destination)
    }

    private func routeToDestination(_ destination: AuthDestination) {
        switch destination {
        case .signup:
            navigateToSignup = true
            logNavigation(destination: destination, route: "signup")
        case .login:
            navigateToLogin = true
            logNavigation(destination: destination, route: "login")
        }
    }

    private func logNavigation(destination: AuthDestination, route: String) {
        SpotLogger.log(
            WelcomeViewLogs.navigationSucceeded,
            details: [
                "destination": destination == .login ? "login" : "signup",
                "route": route
            ]
        )
    }
}

private struct SpotWelcomeBackgroundView: View {
    var body: some View {
        Constants.Colors.background.ignoresSafeArea()
    }
}

private struct SpotWelcomeHeaderView: View {
    let isVisible: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("SPOT")
                .font(FontManager.logoTitle())
                .tracking(6)
                .foregroundColor(Constants.Colors.primary)
                .accessibilityLabel("Spot")

            VStack(spacing: 10) {
                Text("Places hit different when they come from your people.")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundColor(Constants.Colors.primary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.74)

                Text("Save the places you love. Discover the ones your friends can’t stop talking about.")
                    .font(.callout)
                    .foregroundColor(Constants.Colors.welcomeMutedText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 330)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible || reduceMotion ? 0 : 12)
    }
}

private struct WelcomeAuthActionsView: View {
    let appleErrorMessage: String?
    let isTermsAccepted: Bool
    let termsURL: URL
    let privacyURL: URL
    let termsAgreementBinding: Binding<Bool>
    let onAppleRequest: () -> Void
    let onAppleSuccess: () -> Void
    let onAppleError: (String) -> Void
    let onGetStarted: () -> Void
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            AuthPrimaryButton(
                title: "Get started",
                isEnabled: isTermsAccepted,
                action: onGetStarted
            )
            .accessibilityLabel("Get Started")
            .accessibilityIdentifier("onboarding.getStartedButton")

            AuthSecondaryButton(title: "Log in", action: onLogin)
                .accessibilityLabel("Log in")
                .accessibilityIdentifier("auth.loginButton")
                .disabled(!isTermsAccepted)
                .opacity(isTermsAccepted ? 1.0 : 0.45)

            ThemedAppleSignInButton(
                onRequest: onAppleRequest,
                onSuccess: onAppleSuccess,
                onError: onAppleError,
                height: 48
            )
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Sign in with Apple")
            .accessibilityIdentifier("auth.signInWithAppleButton")
            .disabled(!isTermsAccepted)
            .opacity(isTermsAccepted ? 1.0 : 0.45)

            if let appleErrorMessage {
                Text(appleErrorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Authentication error: \(appleErrorMessage)")
            }

            TermsAgreementCheckboxView(
                isAgreed: termsAgreementBinding,
                termsURL: termsURL,
                privacyURL: privacyURL,
                onLinkTapped: nil
            )
            .padding(.top, 2)
        }
    }
}

private struct AuthDividerView: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Constants.Colors.welcomeLine.opacity(0.55))
                .frame(height: 1)

            Text("or")
                .font(.footnote.weight(.medium))
                .foregroundColor(Constants.Colors.welcomeMutedText.opacity(0.82))

            Rectangle()
                .fill(Constants.Colors.welcomeLine.opacity(0.55))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct SpotWelcomeHeroView: View {
    let configuration: WelcomeHeroMotionConfiguration

    @State private var entranceVisible = false

    var body: some View {
        EditorialPlaceCollageView()
            .opacity(entranceVisible ? 1 : 0)
            .scaleEffect(entranceVisible ? 1 : 0.96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A collection of cozy cafes, scenic views, and local favorites shared on Spot.")
        .onAppear(perform: startAnimations)
    }

    private func startAnimations() {
        if configuration.oneTimeEntranceEnabled {
            withAnimation(.easeOut(duration: 0.58)) {
                entranceVisible = true
            }
        } else {
            entranceVisible = true
        }

    }
}

private struct EditorialPlaceCollageView: View {
    var body: some View {
        ZStack {
            EditorialPlaceTile(
                title: "Sunday coffee",
                vibe: "Cozy Corner",
                systemImage: "cup.and.saucer.fill",
                alignment: .bottomLeading
            )
            .frame(width: 190, height: 180)
            .offset(x: -44, y: 4)
            .rotationEffect(.degrees(-3))

            EditorialPlaceTile(
                title: "Golden hour",
                vibe: "Scenic View",
                systemImage: "sun.max.fill",
                alignment: .topTrailing
            )
            .frame(width: 142, height: 154)
            .offset(x: 86, y: -24)
            .rotationEffect(.degrees(4))

            EditorialVibeChip(text: "Local favorite", systemImage: "person.2.fill")
                .offset(x: 76, y: 80)
            EditorialVibeChip(text: "Great coffee", systemImage: "cup.and.saucer.fill")
                .offset(x: -80, y: -78)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EditorialPlaceTile: View {
    let title: String
    let vibe: String
    let systemImage: String
    let alignment: Alignment

    var body: some View {
        ZStack(alignment: alignment) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Constants.Colors.accent)

            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .light))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(Constants.Colors.primary.opacity(0.82))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(vibe)
                .font(.caption2.weight(.semibold))
                .foregroundColor(Constants.Colors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Constants.Colors.welcomeSurface.opacity(0.96))
                .clipShape(Capsule())
                .padding(12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Constants.Colors.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Constants.Colors.welcomeCardShadow, radius: 18, y: 10)
    }
}

private struct EditorialVibeChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundColor(Constants.Colors.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Constants.Colors.welcomeSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Constants.Colors.primary.opacity(0.08), lineWidth: 1))
            .shadow(color: Constants.Colors.welcomeCardShadow, radius: 8, y: 4)
    }
}

private struct ModernMapBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MapGridLinesView()
                    .stroke(Constants.Colors.primary.opacity(0.15), lineWidth: 1.0)

                MapStreetShapesView()
                    .fill(Constants.Colors.accent.opacity(0.5))

                MapAdditionalDetailsView()
                    .fill(Constants.Colors.welcomeGlow.opacity(0.25))

                ForEach(0..<7, id: \.self) { index in
                    MapPinView()
                        .position(
                            x: proxy.size.width * [0.25, 0.65, 0.45, 0.75, 0.35, 0.55, 0.20][index],
                            y: proxy.size.height * [0.3, 0.4, 0.65, 0.7, 0.55, 0.25, 0.75][index]
                        )
                }
            }
        }
    }
}

private struct MapGridLinesView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        for i in stride(from: 0, to: rect.width, by: 40) {
            path.move(to: CGPoint(x: i, y: 0))
            path.addLine(to: CGPoint(x: i, y: rect.height))
        }

        for i in stride(from: 0, to: rect.height, by: 40) {
            path.move(to: CGPoint(x: 0, y: i))
            path.addLine(to: CGPoint(x: rect.width, y: i))
        }

        return path
    }
}

private struct MapStreetShapesView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.addRoundedRect(
            in: CGRect(x: rect.width * 0.15, y: rect.height * 0.25, width: rect.width * 0.3, height: rect.height * 0.08),
            cornerSize: CGSize(width: 8, height: 8)
        )

        path.addRoundedRect(
            in: CGRect(x: rect.width * 0.55, y: rect.height * 0.35, width: rect.width * 0.25, height: rect.height * 0.12),
            cornerSize: CGSize(width: 8, height: 8)
        )

        path.addRoundedRect(
            in: CGRect(x: rect.width * 0.25, y: rect.height * 0.55, width: rect.width * 0.35, height: rect.height * 0.1),
            cornerSize: CGSize(width: 8, height: 8)
        )

        path.addRoundedRect(
            in: CGRect(x: rect.width * 0.65, y: rect.height * 0.65, width: rect.width * 0.2, height: rect.height * 0.08),
            cornerSize: CGSize(width: 8, height: 8)
        )

        path.addRoundedRect(
            in: CGRect(x: rect.width * 0.08, y: rect.height * 0.45, width: rect.width * 0.18, height: rect.height * 0.06),
            cornerSize: CGSize(width: 6, height: 6)
        )

        path.addRoundedRect(
            in: CGRect(x: rect.width * 0.72, y: rect.height * 0.48, width: rect.width * 0.22, height: rect.height * 0.09),
            cornerSize: CGSize(width: 8, height: 8)
        )

        return path
    }
}

private struct MapAdditionalDetailsView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.addEllipse(in: CGRect(x: rect.width * 0.50, y: rect.height * 0.20, width: rect.width * 0.15, height: rect.height * 0.08))

        path.addRoundedRect(
            in: CGRect(x: rect.width * 0.12, y: rect.height * 0.68, width: rect.width * 0.12, height: rect.height * 0.06),
            cornerSize: CGSize(width: 4, height: 4)
        )

        path.addEllipse(in: CGRect(x: rect.width * 0.78, y: rect.height * 0.30, width: rect.width * 0.10, height: rect.height * 0.06))

        return path
    }
}

private struct MapPinView: View {
    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 22, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Constants.Colors.mapMarkerDot, Constants.Colors.mapMarkerGreen)
            .opacity(0.65)
            .shadow(color: Constants.Colors.primary.opacity(0.1), radius: 2, y: 1)
    }
}

private struct FloatingCardsLayerView: View {
    let configuration: WelcomeHeroMotionConfiguration
    let containerSize: CGSize
    let isVisible: Bool
    let floatAnimation: Bool

    private let cards: [(title: String, vibe: String, author: String, offset: CGSize, rotation: Double, delay: Double, gradientType: CardGradientType)] = [
        ("Hidden Cafe", "Cozy Corner", "Noah", CGSize(width: -60, height: -50), -8, 0.0, .cozy),
        ("Sunset Point", "Scenic View", "Jules", CGSize(width: 45, height: -35), 5, 0.15, .scenic),
        ("Beach Spot", "Romantic", "Sarah", CGSize(width: -30, height: 45), -3, 0.3, .beach),
        ("Rooftop Bar", "Late Night", "Alex", CGSize(width: 55, height: 50), 7, 0.45, .night)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                FloatingPlaceCardView(
                    title: card.title,
                    vibeTag: card.vibe,
                    authorName: card.author,
                    gradientType: card.gradientType
                )
                .offset(card.offset)
                .offset(y: floatAnimation ? -8 : 8)
                .rotationEffect(.degrees(card.rotation))
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.85)
                .animation(.easeOut(duration: 0.5).delay(card.delay), value: isVisible)
                .animation(.easeInOut(duration: 3.5 + Double(index) * 0.3).repeatForever(autoreverses: true), value: floatAnimation)
            }
        }
    }
}

enum CardGradientType {
    case cozy, scenic, beach, night
}

private struct FloatingPlaceCardView: View {
    let title: String
    let vibeTag: String
    let authorName: String
    let gradientType: CardGradientType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(gradientForType(gradientType))
                    .frame(width: 140, height: 80)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.3), Color.clear],
                            center: .topLeading,
                            startRadius: 5,
                            endRadius: 60
                        )
                    )
                    .frame(width: 80, height: 80)
                    .offset(x: -20, y: -15)
                    .blendMode(.overlay)

                overlayShapeForType(gradientType)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Constants.Colors.primary)

                HStack(spacing: 4) {
                    Image(systemName: WelcomeHeroContent.systemImage(for: vibeTag))
                        .font(.system(size: 9))
                    Text(vibeTag)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Constants.Colors.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Constants.Colors.welcomeChipFill)
                .clipShape(Capsule())

                HStack(spacing: 4) {
                    Circle()
                        .fill(Constants.Colors.mapMarkerGreen)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(String(authorName.prefix(1)))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Constants.Colors.buttonText)
                        )

                    Text("by \(authorName)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(Constants.Colors.welcomeMutedText)
                }
            }
        }
        .padding(12)
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Constants.Colors.welcomeSurface.opacity(0.95))
                .shadow(color: Constants.Colors.welcomeCardShadow.opacity(0.25), radius: 20, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Constants.Colors.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func gradientForType(_ type: CardGradientType) -> LinearGradient {
        switch type {
        case .cozy:
            return LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.71, blue: 0.55),
                    Color(red: 0.65, green: 0.54, blue: 0.42),
                    Color(red: 0.48, green: 0.40, blue: 0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .scenic:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.75, blue: 0.45),
                    Color(red: 0.95, green: 0.55, blue: 0.35),
                    Color(red: 0.75, green: 0.40, blue: 0.50)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .beach:
            return LinearGradient(
                colors: [
                    Color(red: 0.40, green: 0.70, blue: 0.85),
                    Color(red: 0.50, green: 0.75, blue: 0.80),
                    Color(red: 0.85, green: 0.88, blue: 0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .night:
            return LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.20, blue: 0.35),
                    Color(red: 0.25, green: 0.30, blue: 0.45),
                    Color(red: 0.35, green: 0.35, blue: 0.50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func overlayShapeForType(_ type: CardGradientType) -> some View {
        switch type {
        case .cozy:
            Circle()
                .fill(Color(red: 0.90, green: 0.78, blue: 0.62).opacity(0.4))
                .frame(width: 45, height: 45)
                .offset(x: 35, y: 20)
        case .scenic:
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 80, height: 12)
                .rotationEffect(.degrees(-15))
                .offset(x: 10, y: -10)
        case .beach:
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 30, height: 30)
                .offset(x: -40, y: 25)
        case .night:
            Circle()
                .fill(Color.yellow.opacity(0.6))
                .frame(width: 20, height: 20)
                .offset(x: 45, y: -25)
        }
    }
}

private struct WelcomeGlobeBaseView: View {
    let elapsedTime: TimeInterval
    let continuousAnimationsEnabled: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Constants.Colors.welcomeSurface)
                .overlay(
                    RadialGradient(
                        colors: [
                            Constants.Colors.welcomeGlow.opacity(0.20),
                            Constants.Colors.accent.opacity(0.14),
                            Constants.Colors.primary.opacity(0.04)
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 180
                    )
                )

            WelcomeSpinningLandmassLayer(
                elapsedTime: elapsedTime,
                isAnimated: continuousAnimationsEnabled
            )
            .padding(22)

            WelcomeGlobeGridView()
                .stroke(Constants.Colors.primary.opacity(0.09), lineWidth: 1)
                .padding(18)
        }
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Constants.Colors.primary.opacity(0.08), lineWidth: 1)
        )
        .compositingGroup()
        .shadow(color: Constants.Colors.welcomeCardShadow, radius: 24, y: 14)
    }
}

private struct WelcomeSpinningLandmassLayer: View {
    let elapsedTime: TimeInterval
    let isAnimated: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let progress = isAnimated
                ? elapsedTime.truncatingRemainder(dividingBy: WelcomeHeroSpin.globeSpinCycleDuration) / WelcomeHeroSpin.globeSpinCycleDuration
                : 0
            let offset = CGFloat(progress) * width

            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    WelcomeWorldPatternView()
                        .fill(Constants.Colors.primary.opacity(0.18))
                        .frame(width: width, height: height)
                }
            }
            .offset(x: -offset)
        }
    }
}

private struct WelcomeGlobeGridView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for multiplier in [CGFloat(-0.48), CGFloat(-0.22), CGFloat(0.22), CGFloat(0.48)] {
            let width = radius * 2 * (1 - abs(multiplier) * 0.8)
            path.addEllipse(
                in: CGRect(
                    x: center.x - width / 2,
                    y: center.y - radius,
                    width: width,
                    height: radius * 2
                )
            )
        }

        for multiplier in [CGFloat(-0.44), CGFloat(-0.18), CGFloat(0.18), CGFloat(0.44)] {
            let y = center.y + multiplier * radius * 2
            let latitudeWidth = radius * 2 * sqrt(max(CGFloat(0.12), 1 - multiplier * multiplier))
            path.move(to: CGPoint(x: center.x - latitudeWidth / 2, y: y))
            path.addQuadCurve(
                to: CGPoint(x: center.x + latitudeWidth / 2, y: y),
                control: CGPoint(x: center.x, y: y + multiplier * 16)
            )
        }

        return path
    }
}

private struct WelcomeWorldPatternView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        // North America
        path.move(to: point(0.12, 0.31))
        path.addCurve(to: point(0.27, 0.20), control1: point(0.14, 0.24), control2: point(0.21, 0.20))
        path.addCurve(to: point(0.43, 0.29), control1: point(0.35, 0.19), control2: point(0.41, 0.22))
        path.addCurve(to: point(0.34, 0.42), control1: point(0.45, 0.36), control2: point(0.39, 0.41))
        path.addCurve(to: point(0.23, 0.47), control1: point(0.30, 0.43), control2: point(0.28, 0.48))
        path.addCurve(to: point(0.12, 0.31), control1: point(0.15, 0.45), control2: point(0.10, 0.39))
        path.closeSubpath()

        // Central America bridge
        path.move(to: point(0.33, 0.46))
        path.addCurve(to: point(0.45, 0.51), control1: point(0.38, 0.45), control2: point(0.43, 0.47))
        path.addCurve(to: point(0.39, 0.56), control1: point(0.47, 0.54), control2: point(0.43, 0.57))
        path.addCurve(to: point(0.31, 0.50), control1: point(0.35, 0.55), control2: point(0.32, 0.53))
        path.closeSubpath()

        // South America
        path.move(to: point(0.43, 0.55))
        path.addCurve(to: point(0.52, 0.69), control1: point(0.51, 0.57), control2: point(0.54, 0.63))
        path.addCurve(to: point(0.45, 0.87), control1: point(0.51, 0.78), control2: point(0.46, 0.82))
        path.addCurve(to: point(0.34, 0.68), control1: point(0.36, 0.79), control2: point(0.34, 0.73))
        path.addCurve(to: point(0.43, 0.55), control1: point(0.34, 0.60), control2: point(0.38, 0.55))
        path.closeSubpath()

        // Europe and Africa
        path.move(to: point(0.52, 0.32))
        path.addCurve(to: point(0.65, 0.27), control1: point(0.55, 0.28), control2: point(0.60, 0.27))
        path.addCurve(to: point(0.72, 0.38), control1: point(0.70, 0.29), control2: point(0.73, 0.33))
        path.addCurve(to: point(0.65, 0.45), control1: point(0.70, 0.42), control2: point(0.68, 0.44))
        path.addCurve(to: point(0.71, 0.65), control1: point(0.73, 0.51), control2: point(0.75, 0.59))
        path.addCurve(to: point(0.61, 0.76), control1: point(0.68, 0.70), control2: point(0.64, 0.75))
        path.addCurve(to: point(0.52, 0.58), control1: point(0.55, 0.69), control2: point(0.51, 0.63))
        path.addCurve(to: point(0.52, 0.32), control1: point(0.53, 0.49), control2: point(0.47, 0.40))
        path.closeSubpath()

        // Asia
        path.move(to: point(0.68, 0.30))
        path.addCurve(to: point(0.91, 0.33), control1: point(0.74, 0.20), control2: point(0.87, 0.23))
        path.addCurve(to: point(0.84, 0.52), control1: point(0.96, 0.44), control2: point(0.90, 0.51))
        path.addCurve(to: point(0.72, 0.48), control1: point(0.79, 0.53), control2: point(0.76, 0.48))
        path.addCurve(to: point(0.68, 0.30), control1: point(0.66, 0.43), control2: point(0.63, 0.36))
        path.closeSubpath()

        // Australia
        path.move(to: point(0.78, 0.67))
        path.addCurve(to: point(0.91, 0.68), control1: point(0.82, 0.62), control2: point(0.88, 0.63))
        path.addCurve(to: point(0.86, 0.77), control1: point(0.94, 0.72), control2: point(0.91, 0.77))
        path.addCurve(to: point(0.76, 0.74), control1: point(0.82, 0.78), control2: point(0.78, 0.77))
        path.addCurve(to: point(0.78, 0.67), control1: point(0.74, 0.70), control2: point(0.75, 0.68))
        path.closeSubpath()

        return path
    }
}

private struct OrbitingItemView: View {
    let item: OrbitingItem
    let pulse: Bool

    var body: some View {
        switch item.kind {
        case .tag(let text, let icon):
            WelcomeVibeChipView(text: text, systemImage: icon)
        case .avatar(let initials, let palette):
            WelcomeAvatarBubbleView(initials: initials, colors: avatarColors(for: palette))
        case .pin(let isHighlighted):
            WelcomeSpotPinView(isHighlighted: isHighlighted, pulse: pulse)
        case .card(let title, let subtitle, let meta):
            WelcomeMiniSpotCardView(title: title, subtitle: subtitle, meta: meta)
        }
    }

    private func avatarColors(for palette: Int) -> [Color] {
        switch palette {
        case 1:
            return [Constants.Colors.welcomeGlow, Constants.Colors.accent]
        default:
            return [Constants.Colors.primary, Constants.Colors.welcomeGlow]
        }
    }
}

private struct WelcomeSpotPinView: View {
    let isHighlighted: Bool
    let pulse: Bool

    var body: some View {
        ZStack {
            if isHighlighted {
                Circle()
                    .fill(Constants.Colors.welcomeGlow.opacity(0.22))
                    .frame(width: 48, height: 48)
                    .scaleEffect(pulse ? 1.18 : 0.86)
                    .opacity(pulse ? 0.18 : 0.52)
            }

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: isHighlighted ? 34 : 28, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Constants.Colors.mapMarkerDot, Constants.Colors.mapMarkerGreen)
                .shadow(color: Constants.Colors.primary.opacity(0.16), radius: 8, y: 4)
        }
        .accessibilityHidden(true)
    }
}

private struct WelcomeAvatarBubbleView: View {
    let initials: String
    let colors: [Color]

    var body: some View {
        Text(initials)
            .font(.caption.weight(.bold))
            .foregroundColor(Constants.Colors.buttonText)
            .frame(width: 42, height: 42)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Constants.Colors.buttonText.opacity(0.9), lineWidth: 2))
            .shadow(color: Constants.Colors.welcomeCardShadow, radius: 12, y: 6)
            .accessibilityHidden(true)
    }
}

private struct WelcomeVibeChipView: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(Constants.Colors.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Constants.Colors.welcomeChipFill)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Constants.Colors.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: Constants.Colors.welcomeCardShadow, radius: 10, y: 5)
        .accessibilityHidden(true)
    }
}

private struct WelcomeMiniSpotCardView: View {
    let title: String
    let subtitle: String
    let meta: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(Constants.Colors.primary)
                Spacer()
                Image(systemName: "bookmark.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Constants.Colors.primary)
            }

            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundColor(Constants.Colors.welcomeMutedText)

            Text(meta)
                .font(.caption2)
                .foregroundColor(Constants.Colors.welcomeMutedText.opacity(0.86))
        }
        .padding(14)
        .background(Constants.Colors.welcomeSurface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Constants.Colors.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Constants.Colors.welcomeCardShadow, radius: 16, y: 8)
        .accessibilityHidden(true)
    }
}

private struct TopographicLinesView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let horizontalScale = rect.width / 390
        let verticalScale = rect.height / 844

        for index in 0..<6 {
            let y = CGFloat(index) * 112 * verticalScale + 34
            path.move(to: CGPoint(x: -30, y: y))
            path.addCurve(
                to: CGPoint(x: rect.width + 30, y: y + 44 * verticalScale),
                control1: CGPoint(x: 110 * horizontalScale, y: y - 42 * verticalScale),
                control2: CGPoint(x: 270 * horizontalScale, y: y + 88 * verticalScale)
            )
        }

        return path
    }
}

private extension View {
    func welcomeEntrance(_ isVisible: Bool, delay: Double) -> some View {
        opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.86)
            .animation(.easeOut(duration: 0.44).delay(delay), value: isVisible)
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthViewModel())
}

#Preview("Compact Height") {
    WelcomeView()
        .environmentObject(AuthViewModel())
        .frame(height: 667)
}

#Preview("Large Dynamic Type") {
    WelcomeView()
        .environmentObject(AuthViewModel())
        .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Reduce Motion Static Hero") {
    SpotWelcomeHeroView(configuration: .resolved(reduceMotionEnabled: true))
        .frame(height: 300)
        .padding()
        .background(Constants.Colors.background)
}

#Preview("Terms Gate Disabled") {
    PreAuthTermsAgreementStore.shared.setAgreed(false)
    return WelcomeView()
        .environmentObject(AuthViewModel())
}
