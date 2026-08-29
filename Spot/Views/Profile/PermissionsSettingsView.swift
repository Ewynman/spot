//
//  PermissionsSettingsView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct PermissionsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var permissionManager = PermissionManager.shared

    /// Indirection over `UIApplication.openSettingsURLString` so unit tests
    /// can verify the row actions without launching the iOS Settings app.
    private let settingsOpener: AppSettingsOpening

    init(settingsOpener: AppSettingsOpening = UIApplicationSettingsOpener.shared) {
        self.settingsOpener = settingsOpener
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    introCard

                    ForEach(SpotPermissionType.allCases, id: \.self) { type in
                        PermissionRowCard(
                            type: type,
                            status: permissionManager.status(for: type),
                            onOpenSettings: { settingsOpener.openAppSettings() }
                        )
                        .accessibilityIdentifier("permissions.row.\(type.rawValue)")
                    }
                }
                .padding(16)
            }
        }
        .background(Constants.Colors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("permissions.screenRoot")
        .onAppear {
            // Pull a fresh snapshot when the screen opens. We never request
            // permissions automatically here — App Review specifically calls
            // out auto-prompts from Settings as inappropriate.
            permissionManager.updatePermissionStatuses()
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
            }
            .buttonStyle(PlainButtonStyle())

            Text("Permissions")
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)
                .frame(maxWidth: .infinity)

            Spacer().frame(width: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions are optional")
                .font(FontManager.primaryText())
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.primary)
            Text("Spot keeps working when these are off. Tap a row to open iOS Settings if you want to change anything later.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private struct PermissionRowCard: View {
    let type: SpotPermissionType
    let status: SpotPermissionStatus
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: type.settingsIcon)
                    .font(.system(size: 20))
                    .foregroundColor(Constants.Colors.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayTitle)
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)

                    Text(status.statusLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(status.needsAttention ? .orange : .gray)
                        .accessibilityIdentifier("permissions.status.\(type.rawValue)")
                }

                Spacer()

                if status.needsAttention {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                        .accessibilityLabel("\(type.displayTitle) needs attention")
                        .accessibilityIdentifier("permissions.warning.\(type.rawValue)")
                }
            }

            Text(type.detailExplanation)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if status != .authorized {
                Button(action: onOpenSettings) {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Open iOS Settings")
                            .font(FontManager.primaryText())
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Constants.Colors.primary)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("permissions.openSettings.\(type.rawValue)")
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview("All authorized") {
    PermissionsSettingsView()
}
