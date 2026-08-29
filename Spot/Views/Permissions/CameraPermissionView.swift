//
//  CameraPermissionView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import AVFoundation

struct CameraPermissionView: View {
    let authDestination: NotificationPermissionView.AuthDestination
    let onComplete: (() -> Void)?
    let showsBackButton: Bool
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var permissionManager: PermissionManager
    @State private var navigateToSignup = false
    @State private var navigateToLogin = false
    @State private var navigateToPostAuthSetup = false

    init(
        authDestination: NotificationPermissionView.AuthDestination,
        showsBackButton: Bool = true,
        onComplete: (() -> Void)? = nil
    ) {
        self.authDestination = authDestination
        self.showsBackButton = showsBackButton
        self.onComplete = onComplete
    }

    private var isDenied: Bool {
        permissionManager.cameraStatus == .denied || permissionManager.cameraStatus == .restricted
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
                        CustomBackButton { dismiss() }
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)
                } else {
                    Spacer().frame(height: 16)
                }

                VStack(spacing: 8) {
                    Text(PermissionPrePromptStrings.Camera.title)
                        .font(FontManager.sectionHeader())
                        .foregroundColor(Constants.Colors.primary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Text(PermissionPrePromptStrings.Camera.body)
                    .font(FontManager.primaryText())
                    .multilineTextAlignment(.center)
                    .foregroundColor(Constants.Colors.primary)
                    .padding(.horizontal, 24)

                if isDenied {
                    Text(PermissionPrePromptStrings.Camera.deniedBody)
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
                    .accessibilityIdentifier("permission.camera.primaryButton")

                    // PRD §11.3: the immediate pre-permission screen must
                    // not surface a `Skip` / `Continue Without ...` style
                    // bypass. The `Continue Without Camera` action is only
                    // shown once the user has actually denied access.
                    if isDenied {
                        Button(action: { routeToDestination() }) {
                            Text(PermissionPrePromptStrings.Camera.secondaryAction)
                                .font(FontManager.buttonText())
                                .foregroundColor(Constants.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("permission.camera.secondaryButton")
                    }
                }
                .padding(.horizontal, 32)
                Spacer()
            }
            .padding(.top)
        }
        .navigationDestination(isPresented: $navigateToSignup) { SignupView() }
        .navigationDestination(isPresented: $navigateToLogin) { LoginView() }
        .navigationDestination(isPresented: $navigateToPostAuthSetup) { PostAuthSetupFlowView(onComplete: {}) }
        .onAppear {
            permissionManager.updatePermissionStatuses()
        }
        .onChange(of: permissionManager.cameraStatus) { _, newStatus in
            if newStatus != .notDetermined {
                routeToDestination()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func primaryAction() {
        if isDenied {
            permissionManager.openCameraSettings()
        } else {
            permissionManager.requestCameraPermission()
        }
    }

    private func routeToDestination() {
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
    CameraPermissionView(authDestination: .signup)
        .environmentObject(PermissionManager.shared)
}
