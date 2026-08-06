//
//  ProfileReportSheet.swift
//  Spot
//
//  Sheet for reporting another user (profile-level), separate from the
//  spot-level `ReportSheet`. Uses `ModerationService.submitProfileReport`
//  which writes to `public.reports` with `target_type = 'profile'` and
//  records a `moderation_events` row via the underlying trigger.
//

import SwiftUI

struct ProfileReportSheet: View {
    let reportedUserId: UUID
    let reportedUsername: String?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var selectedReason: ModerationReportReason?
    @State private var details: String = ""
    @State private var shouldBlockUser: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false

    private let service: ModerationServicing

    init(reportedUserId: UUID,
         reportedUsername: String? = nil,
         service: ModerationServicing = ModerationService.shared) {
        self.reportedUserId = reportedUserId
        self.reportedUsername = reportedUsername
        self.service = service
    }

    private var reasons: [ModerationReportReason] {
        [
            .harassmentOrAbuse,
            .hateSpeechOrDiscrimination,
            .sexualOrNudeContent,
            .violenceOrThreats,
            .spamOrScam,
            .illegalContent,
            .privateInformation,
            .other
        ]
    }

    private var canSubmit: Bool {
        guard let reason = selectedReason, !isSubmitting else { return false }
        if reason == .other && details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    reasonCard
                    detailsCard
                    blockCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Constants.Colors.background)
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)
                        .disabled(isSubmitting)
                        .buttonStyle(.plain)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                submitBar
            }
        }
        .tint(Constants.Colors.primary)
        .background(Constants.Colors.background)
        .alert("Report Submitted", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Thanks — our moderation team will review this report within 24 hours.")
        }
        .alert("Couldn't send report", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
        .onChange(of: details) { _, newValue in
            if newValue.count > 500 {
                details = String(newValue.prefix(500))
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let username = reportedUsername, !username.isEmpty {
                Text("Reporting @\(username)")
                    .font(FontManager.primaryText())
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.primary)
            } else {
                Text("Reporting this user")
                    .font(FontManager.primaryText())
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.primary)
            }
            Text("Reports are confidential. Spot's moderation team will review and act within 24 hours when appropriate.")
                .font(FontManager.primaryText())
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 1))
    }

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why are you reporting this user?")
                .font(FontManager.primaryText())
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.primary)

            VStack(spacing: 0) {
                ForEach(Array(reasons.enumerated()), id: \.element) { index, reason in
                    reasonRow(for: reason)
                    if index < reasons.count - 1 {
                        Divider().background(Color.gray.opacity(0.25))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 1))
    }

    private func reasonRow(for reason: ModerationReportReason) -> some View {
        Button {
            selectedReason = reason
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(displayLabel(for: reason))
                    .font(FontManager.primaryText())
                    .multilineTextAlignment(.leading)
                    .foregroundColor(Constants.Colors.primary)
                Spacer(minLength: 8)
                if selectedReason == reason {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .accessibilityIdentifier("profileReport.reason.\(reason.rawValue)")
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Additional details (optional)")
                .font(FontManager.primaryText())
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.primary)

            ZStack(alignment: .topLeading) {
                if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Add context…")
                        .font(FontManager.primaryText())
                        .foregroundColor(.gray)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $details)
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .disabled(isSubmitting)
            }
            .padding(10)
            .background(Color(hex: "FAFAF8"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.25), lineWidth: 1))

            Text("\(details.count)/500 characters")
                .font(FontManager.primaryText())
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 1))
    }

    private var blockCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Also block this user")
                        .font(FontManager.primaryText())
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                    Text("You won't see their profile or Spots.")
                        .font(FontManager.primaryText())
                        .foregroundColor(.gray)
                }
                Spacer(minLength: 12)
                Toggle("Also block this user", isOn: $shouldBlockUser)
                    .labelsHidden()
                    .accessibilityLabel("Also block this user")
                    .disabled(isSubmitting)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 1))
    }

    private var submitBar: some View {
        VStack(spacing: 0) {
            Button {
                Task { await submitReport() }
            } label: {
                Text(isSubmitting ? "Submitting…" : "Submit Report")
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? Constants.Colors.primary : Constants.Colors.primary.opacity(0.35))
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .accessibilityIdentifier("profileReport.submitButton")
        }
        .background(Constants.Colors.background)
    }

    @MainActor
    private func submitReport() async {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        do {
            _ = try await service.submitProfileReport(
                reportedUserId: reportedUserId,
                reason: reason,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                blockRequested: shouldBlockUser
            )

            if shouldBlockUser {
                try await authVM.blockUser(userId: reportedUserId.uuidString)
                NotificationCenter.default.post(
                    name: .homeFeedLocallyRemove,
                    object: nil,
                    userInfo: [SpotHomeFeedNotification.authorUserIdKey: reportedUserId.uuidString]
                )
            }

            isSubmitting = false
            showSuccess = true
        } catch {
            isSubmitting = false
            showError = true
        }
    }

    private func displayLabel(for reason: ModerationReportReason) -> String {
        switch reason {
        case .harassmentOrAbuse: return "Harassment or abuse"
        case .hateSpeechOrDiscrimination: return "Hate speech or discrimination"
        case .sexualOrNudeContent: return "Sexual or nude content"
        case .violenceOrThreats: return "Violence or threats"
        case .spamOrScam: return "Spam or scam"
        case .illegalContent: return "Illegal content"
        case .privateInformation: return "Private information"
        case .other: return "Other"
        // Legacy spot reasons - fall through to readable strings, even though
        // the profile sheet doesn't surface them directly.
        case .inappropriate: return "Inappropriate / nudity"
        case .harassment: return "Harassment or hate"
        case .violence: return "Violence / dangerous acts"
        case .spam: return "Spam or scams"
        case .misinformation: return "Misinformation"
        case .privacy: return "Privacy / personal data"
        }
    }
}

#Preview {
    let auth = AuthViewModel()
    auth.userId = UUID().uuidString
    return ProfileReportSheet(
        reportedUserId: UUID(),
        reportedUsername: "exampleuser"
    )
    .environmentObject(auth)
}
