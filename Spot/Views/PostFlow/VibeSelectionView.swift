import SwiftUI

struct VibeSelectionView: View {
    @Binding var selectedVibes: [String]
    let maxVibes: Int
    @EnvironmentObject var authVM: AuthViewModel
    @State private var customVibe: String = ""
    @State private var validationMessage: String?
    @State private var recentAndFrequent: [String] = []

    private let vibeTags = Constants.VibeTags.defaultTags

    var body: some View {
        VStack(spacing: Constants.Layout.Spacing.large) {
            // Header
            VStack(spacing: 8) {
                Text("Pick Your Vibe")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)

                Text(
                    authVM.isPro
                        ? "Select up to \(maxVibes) vibes that best capture your spot."
                        : "Select one vibe that best captures your spot."
                )
                    .font(FontManager.primaryText())
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Constants.Layout.Padding.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("\(selectedVibes.count)/\(maxVibes) selected")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal, Constants.Layout.Padding.horizontal)

                    customVibeInput

                    if !recentAndFrequent.isEmpty {
                        vibeSection(
                            title: "Recent & Frequent",
                            vibes: recentAndFrequent
                        )
                    }

                    if authVM.isPro, !authVM.customVibeTags.isEmpty {
                        vibeSection(
                            title: "Your Vibes",
                            vibes: authVM.customVibeTags
                        )
                    }

                    VStack(alignment: .leading, spacing: Constants.Layout.Spacing.small) {
                        Text("Default Vibes")
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary)
                            .padding(.horizontal, Constants.Layout.Padding.horizontal)
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(vibeTags.filter { !authVM.customVibeTags.contains($0) }, id: \.self) { vibe in
                                VibeTagButton(
                                    vibe: vibe,
                                    isSelected: selectedVibes.contains(vibe),
                                    onTap: {
                                        SpotLogger.log(VibeSelectionViewLogs.vibeSelected, details: ["vibe": vibe])
                                        toggleVibe(vibe)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, Constants.Layout.Padding.horizontal)
                    }

                    if let msg = validationMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, Constants.Layout.Padding.horizontal)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 140)
            }
        }
        .onAppear {
            reloadRecentAndFrequent()
        }
        .onChange(of: selectedVibes) { _, _ in
            reloadRecentAndFrequent()
        }
    }

    private func useCustomVibe() {
        guard authVM.isPro else {
            NotificationCenter.default.post(name: .showPaywall, object: nil)
            return
        }
        let validator = VibeTagValidator()
        switch validator.validate(customVibe) {
        case .ok(let tag):
            validationMessage = nil
            toggleVibe(tag)
            // Persist globally and on the user profile for reuse
            Task {
                await VibeTagService.shared.ensureExistsAndAttachToUser(name: tag, userId: authVM.userId)
                // Optimistic local update so it shows under "Your tags" immediately
                await MainActor.run {
                    if !authVM.customVibeTags.contains(tag) {
                        authVM.customVibeTags.append(tag)
                    }
                }
            }
            customVibe = ""
            reloadRecentAndFrequent()
        case .tooShort:
            validationMessage = Constants.ValidationMessages.vibeTooShort
        case .tooLong:
            validationMessage = Constants.ValidationMessages.vibeTooLong
        case .blocked:
            validationMessage = Constants.ValidationMessages.vibeBlocked
        }
    }

    private func toggleVibe(_ vibe: String) {
        let outcome = VibeSelectionPolicy.toggle(
            current: selectedVibes,
            vibe: vibe,
            isPro: authVM.isPro,
            maxVibes: maxVibes
        )
        if outcome.validationMessage == Constants.PostLimits.freeMultipleVibesMessage {
            AnalyticsService.shared.logEvent("post_multiple_vibes_upsell_shown", parameters: [:])
        } else if outcome.validationMessage == Constants.PostLimits.proTooManyVibesMessage {
            AnalyticsService.shared.logEvent("post_vibe_limit_reached", parameters: ["max": maxVibes])
        }
        selectedVibes = outcome.selectedVibes
        validationMessage = outcome.validationMessage
        if outcome.didChange {
            reloadRecentAndFrequent()
        }
    }

    private var customVibeInput: some View {
        VStack(spacing: Constants.Layout.Spacing.small) {
            HStack {
                Text("Create a custom vibe")
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                Spacer()
                Text("\(customVibe.count)/\(Constants.Limits.vibeTagMaxLength)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, Constants.Layout.Padding.horizontal)

            HStack(spacing: Constants.Layout.Spacing.small) {
                TextField("e.g. Golden Hour", text: $customVibe)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .foregroundColor(Constants.Colors.primary)
                    .padding(Constants.Layout.Padding.verticalMedium)
                    .background(Color.white)
                    .cornerRadius(Constants.Layout.CornerRadius.medium)
                    .overlay(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium).stroke(Constants.Colors.primary, lineWidth: 1))

                Button(action: useCustomVibe) {
                    Text("Use")
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .padding(.horizontal, Constants.Layout.Padding.verticalMedium)
                        .padding(.vertical, Constants.Layout.Padding.verticalSmall)
                        .background(Constants.Colors.primary)
                        .cornerRadius(Constants.Layout.CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, Constants.Layout.Padding.horizontal)
        }
    }

    private func vibeSection(title: String, vibes: [String]) -> some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.small) {
            Text(title)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
                .padding(.horizontal, Constants.Layout.Padding.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Constants.Layout.Spacing.medium) {
                ForEach(vibes, id: \.self) { vibe in
                    VibeTagButton(
                        vibe: vibe,
                        isSelected: selectedVibes.contains(vibe),
                        onTap: {
                            SpotLogger.log(VibeSelectionViewLogs.vibeSelected, details: ["vibe": vibe])
                            toggleVibe(vibe)
                        }
                    )
                }
            }
            .padding(.horizontal, Constants.Layout.Padding.horizontal)
        }
    }

    private func reloadRecentAndFrequent() {
        recentAndFrequent = VibeTagUsageStore.recentAndFrequent(excluding: selectedVibes)
    }
}

// MARK: - Vibe Tag Button
struct VibeTagButton: View {
    let vibe: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(vibe)
                .font(FontManager.primaryText())
                .foregroundColor(isSelected ? .white : Constants.Colors.primary)
                .padding(.horizontal, Constants.Layout.Padding.verticalLarge)
                .padding(.vertical, Constants.Layout.Padding.verticalMedium)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large)
                        .fill(isSelected ? Constants.Colors.primary : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large)
                        .stroke(Constants.Colors.primary, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VibeSelectionView(selectedVibes: .constant([]), maxVibes: 3)
}
