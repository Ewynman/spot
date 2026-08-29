//
//  NotificationPermissionView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct NotificationPermissionView: View {
    enum AuthDestination {
        case signup
        case login
        case postAuthSetup
    }

    let authDestination: AuthDestination
    let onComplete: (() -> Void)?
    let showsBackButton: Bool
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var permissionManager: PermissionManager
    @State private var navigateToSignup = false
    @State private var navigateToLogin = false
    @State private var navigateToPostAuthSetup = false

    init(
        authDestination: AuthDestination = .signup,
        showsBackButton: Bool = true,
        onComplete: (() -> Void)? = nil
    ) {
        self.authDestination = authDestination
        self.showsBackButton = showsBackButton
        self.onComplete = onComplete
    }

    private var isDeniedOrPartial: Bool {
        switch permissionManager.notificationStatus {
        case .denied, .provisional, .ephemeral: return true
        default: return false
        }
    }

    private var primaryButtonTitle: String {
        isDeniedOrPartial ? PermissionPrePromptStrings.openSettingsButton : PermissionPrePromptStrings.continueButton
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
                    Text(PermissionPrePromptStrings.Notifications.title)
                        .font(FontManager.sectionHeader())
                        .foregroundColor(Constants.Colors.primary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Text(PermissionPrePromptStrings.Notifications.body)
                    .font(FontManager.primaryText())
                    .multilineTextAlignment(.center)
                    .foregroundColor(Constants.Colors.primary)
                    .padding(.horizontal, 24)

                if isDeniedOrPartial {
                    Text(PermissionPrePromptStrings.Notifications.deniedBody)
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
                    .accessibilityIdentifier("permission.notifications.primaryButton")

                    // PRD §13.5: the immediate pre-permission screen must
                    // not surface a `Skip` / `Open Settings` / `Continue
                    // Without ...` bypass. We only show the
                    // `Continue Without Notifications` recovery affordance
                    // once the user has actually denied (or been auto-
                    // routed into a partial state).
                    if isDeniedOrPartial {
                        Button(action: { goToAuthDestination() }) {
                            Text(PermissionPrePromptStrings.Notifications.secondaryAction)
                                .font(FontManager.buttonText())
                                .foregroundColor(Constants.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("permission.notifications.secondaryButton")
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
        .onChange(of: permissionManager.notificationStatus) { _, newStatus in
            if newStatus != .notDetermined {
                goToAuthDestination()
            }
        }
    }

    private func primaryAction() {
        if isDeniedOrPartial {
            permissionManager.openNotificationSettings()
        } else {
            permissionManager.requestNotificationPermission()
        }
    }

    private func goToAuthDestination() {
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
    NotificationPermissionView()
        .environmentObject(PermissionManager.shared)
}
