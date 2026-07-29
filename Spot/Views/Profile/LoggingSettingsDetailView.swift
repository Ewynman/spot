//
//  LoggingSettingsDetailView.swift
//  Spot
//
//  DEBUG-only root logging profile control.
//

import SwiftUI

#if DEBUG
struct LoggingSettingsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.UserDefaultsKeys.loggingProfile)
    private var loggingProfile = LoggingProfile.information.rawValue

    private var selectedProfile: LoggingProfile {
        LoggingProfile(rawValue: loggingProfile) ?? .errorsOnly
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsTopBar(title: "Logging", dismiss: dismiss)
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Log profile")
                            Picker("Log profile", selection: $loggingProfile) {
                                ForEach(LoggingProfile.allCases) { profile in
                                    Text(profile.title).tag(profile.rawValue)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                            .accessibilityIdentifier("settings.logging.profile")

                            Text(selectedProfile.summary)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    settingsSection {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Device log file")
                            Text(
                                "When a DEBUG build runs without Xcode attached, logs appear in Files → On My iPhone → Spot → Logs → spot-debug.txt. They are also available through Finder when the phone is connected to a Mac. Files rotate at 1 MB and retain three archives."
                            )
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    settingsSection {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Release behavior")
                            Text("App Store and TestFlight builds always use profile 0 — Errors only.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Constants.Colors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onChange(of: loggingProfile) { _, _ in
            LoggingConfig.applyFromUserDefaults()
        }
    }
}

private func settingsTopBar(title: String, dismiss: DismissAction) -> some View {
    HStack {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Constants.Colors.primary)
        }
        .buttonStyle(PlainButtonStyle())

        Text(title)
            .font(FontManager.sectionHeader())
            .foregroundColor(Constants.Colors.primary)
            .frame(maxWidth: .infinity)

        Spacer().frame(width: 40)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
}

private func sectionHeader(_ title: String) -> some View {
    HStack {
        Text(title)
            .font(FontManager.sectionHeader())
            .fontWeight(.semibold)
            .foregroundColor(Constants.Colors.primary)
        Spacer()
    }
}

private func settingsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        content()
    }
    .padding(16)
    .background(Color.white)
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
}

#Preview {
    NavigationStack {
        LoggingSettingsDetailView()
    }
}
#endif
