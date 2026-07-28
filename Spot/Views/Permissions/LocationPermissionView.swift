//
//  LocationPermissionView.swift
//  Spot
//
//  Custom pre-permission screen for Location. Apple App Review
//  (Guidelines 5.1.1 / 5.1.5) requires:
//   * Neutral primary button copy (`Continue`).
//   * No `Maybe Later` immediately before the native iOS permission prompt.
//   * No `Enable Location` / `Allow Location` wording.
//   * Location must remain optional — denial routes to the rest of the app
//     with a continental US map fallback.
//
//  This view used to gate onboarding. It is retained for contextual
//  pre-prompts (first-run map tour, map recenter, etc.) but no longer
//  blocks any post-auth flow.
//

import SwiftUI

struct LocationPermissionView: View {
    enum AuthDestination {
        case signup
        case login
        case postAuthSetup
    }

    let authDestination: AuthDestination
    /// When provided, the view calls `onComplete()` instead of pushing a
    /// `navigationDestination`. This lets a parent (e.g. `RootView`) drive a
    /// linear chain of permission steps without each view forcing its own
    /// navigation stack.
    let onComplete: (() -> Void)?
    let showsBackButton: Bool
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var permissionManager: PermissionManager
    @State private var navigateToSignup = false
    @State private var navigateToLogin = false
    @State private var navigateToPostAuthSetup = false
    @State private var hasFinished = false

    init(
        authDestination: AuthDestination = .signup,
        showsBackButton: Bool = true,
        onComplete: (() -> Void)? = nil
    ) {
        self.authDestination = authDestination
        self.showsBackButton = showsBackButton
        self.onComplete = onComplete
    }

    private var isDenied: Bool {
        permissionManager.locationStatus == .denied || permissionManager.locationStatus == .restricted
    }

    private var primaryButtonTitle: String {
        isDenied ? PermissionPrePromptStrings.openSettingsButton : PermissionPrePromptStrings.continueButton
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(spacing: 22) {
                if showsBackButton {
                    HStack {
                        CustomBackButton {
                            dismiss()
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)
                } else {
                    Spacer().frame(height: 16)
                }

                VStack(spacing: 8) {
                    Text(PermissionPrePromptStrings.Location.title)
                        .font(FontManager.sectionHeader())
                        .foregroundColor(Constants.Colors.primary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Text(PermissionPrePromptStrings.Location.body)
                    .font(FontManager.primaryText())
                    .multilineTextAlignment(.center)
                    .foregroundColor(Constants.Colors.primary)
                    .padding(.horizontal, 24)

                if isDenied {
                    Text(PermissionPrePromptStrings.Location.deniedBody)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Image("waves")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 0)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: primaryAction) {
                        Text(primaryButtonTitle)
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Constants.Colors.primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("permission.location.primaryButton")

                    // PRD §12.5: the immediate pre-permission screen must
                    // not surface a `Skip` / `Continue Without ...` style
                    // bypass. The `Continue Without Location` action is
                    // only valid as a denied-state recovery affordance.
                    if isDenied {
                        Button(action: { goToAuthDestination() }) {
                            Text(PermissionPrePromptStrings.Location.secondaryAction)
                                .font(FontManager.buttonText())
                                .foregroundColor(Constants.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("permission.location.secondaryButton")
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top)
        }
        .navigationDestination(isPresented: $navigateToSignup) {
            SignupView()
        }
        .navigationDestination(isPresented: $navigateToLogin) {
            LoginView()
        }
        .navigationDestination(isPresented: $navigateToPostAuthSetup) {
            PostAuthSetupFlowView(onComplete: {})
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            permissionManager.updatePermissionStatuses()
        }
        .onChange(of: permissionManager.locationStatus) { _, newStatus in
            // Once the user makes any choice (allow or deny), we proceed to
            // the original destination so the screen doesn't sit indefinitely
            // after the native iOS prompt closes.
            if newStatus != .notDetermined {
                goToAuthDestination()
            }
        }
    }

    private func primaryAction() {
        permissionManager.updatePermissionStatuses()
        switch LocationPermissionPolicy.primaryAction(for: permissionManager.locationStatus) {
        case .complete:
            // A stale parent decision can present this sheet after access was
            // already granted. Complete immediately instead of waiting for an
            // authorization change that will never occur.
            goToAuthDestination()
        case .openSettings:
            permissionManager.openLocationSettings()
        case .requestSystemPermission:
            permissionManager.requestLocationPermission()
        }
    }

    private func goToAuthDestination() {
        guard !hasFinished else { return }
        hasFinished = true
        if let onComplete {
            onComplete()
            return
        }
        switch authDestination {
        case .signup:
            navigateToSignup = true
        case .login:
            navigateToLogin = true
        case .postAuthSetup:
            navigateToPostAuthSetup = true
        }
    }
}

#Preview {
    LocationPermissionView()
        .environmentObject(PermissionManager.shared)
}
