//
//  ReportSheet.swift
//  Spot
//
//  Created by Edward Wynman on 8/14/25.
//

import SwiftUI
import Supabase

enum ReportReason: String, CaseIterable {
    case inappropriate = "inappropriate"
    case harassment = "harassment"
    case violence = "violence"
    case spam = "spam"
    case misinformation = "misinformation"
    case privacy = "privacy"
    case other = "other"

    var title: String {
        switch self {
        case .inappropriate:
            return "Inappropriate / Nudity or Sexual Content"
        case .harassment:
            return "Harassment or Hate"
        case .violence:
            return "Violence / Dangerous Acts / Drugs"
        case .spam:
            return "Spam or Scams"
        case .misinformation:
            return "Misinformation / Illegal Activity"
        case .privacy:
            return "Privacy / Personal Data"
        case .other:
            return "Other"
        }
    }

    /// Bridges the legacy spot-report reason to the canonical
    /// `ModerationReportReason` accepted by `submit_content_report`.
    fileprivate var moderationReason: ModerationReportReason {
        switch self {
        case .inappropriate: return .inappropriate
        case .harassment: return .harassment
        case .violence: return .violence
        case .spam: return .spam
        case .misinformation: return .misinformation
        case .privacy: return .privacy
        case .other: return .other
        }
    }
}

#Preview {
    let sample = Spot(
        id: "s1",
        userId: "author1",
        username: "author",
        imageURL: "https://picsum.photos/seed/report/800/600",
        vibeTag: "Scenic",
        latitude: 47.6062,
        longitude: -122.3321,
        locationName: "Seattle",
        createdAt: Date()
    )
    let auth = AuthViewModel()
    auth.userId = "viewer1"
    return ReportSheet(spot: sample)
        .environmentObject(auth)
}

struct ReportSheet: View {
    let spot: Spot
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedReason: ReportReason?
    @State private var details: String = ""
    @State private var shouldBlockUser: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showSuccessMessage: Bool = false
    @State private var showSubmitError: Bool = false

    private let moderationService: ModerationServicing

    init(spot: Spot, moderationService: ModerationServicing = ModerationService.shared) {
        self.spot = spot
        self.moderationService = moderationService
    }

    private let reasons: [ReportReason] = [
        .inappropriate,
        .harassment,
        .violence,
        .spam,
        .misinformation,
        .privacy,
        .other
    ]

    private var canSubmit: Bool {
        guard let reason = selectedReason else { return false }
        if reason == .other && details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return !isSubmitting
    }

    private var isOwnSpot: Bool {
        guard let currentUserId = authVM.userId, let ownerId = spot.userId else { return false }
        return currentUserId == ownerId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isOwnSpot {
                        ownSpotMessage
                    } else {
                        reasonCard
                        detailsCard
                        blockCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Constants.Colors.background)
            .navigationTitle("Report Spot")
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
                if !isOwnSpot {
                    submitBar
                }
            }
        }
        .tint(Constants.Colors.primary)
        .background(Constants.Colors.background)
        .alert("Report Submitted", isPresented: $showSuccessMessage) {
            Button("OK") { dismiss() }
        } message: {
            Text("Thanks for helping keep our community safe.")
        }
        .alert("Couldn't send report", isPresented: $showSubmitError) {
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

    // MARK: - Sections

    private var ownSpotMessage: some View {
        Text("You cannot report your own spot.")
            .font(FontManager.primaryText())
            .foregroundColor(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 1))
    }

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reason for reporting")
                .font(FontManager.primaryText())
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.primary)

            VStack(spacing: 0) {
                ForEach(Array(reasons.enumerated()), id: \.element) { index, reason in
                    reasonRow(for: reason)
                    if index < reasons.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.25))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 1))
    }

    private func reasonRow(for reason: ReportReason) -> some View {
        Button {
            selectedReason = reason
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(reason.title)
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
                Text(isSubmitting ? "Submitting…" : "Submit")
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
        }
        .background(Constants.Colors.background)
    }

    @MainActor
    private func submitReport() async {
        guard let reason = selectedReason,
              let ownerId = spot.userId,
              let spotId = spot.id else {
            SpotLogger.log(ReportSheetLogs.submissionMissingRequiredData)
            return
        }

        isSubmitting = true

        do {
            guard let ownerUUID = UUID(uuidString: ownerId),
                  let spotUUID = UUID(uuidString: spotId) else {
                throw NSError(domain: "ReportSheet", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid report IDs"])
            }

            // Route through `submit_content_report` RPC so a `moderation_events`
            // row + correct priority are created server-side. This is the path
            // that satisfies App Review Guideline 1.2.
            _ = try await moderationService.submitSpotReport(
                spotId: spotUUID,
                ownerId: ownerUUID,
                reason: reason.moderationReason,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                blockRequested: shouldBlockUser
            )

            if shouldBlockUser {
                try await authVM.blockUser(userId: ownerId)
                SpotLogger.log(ReportSheetLogs.userBlockedDuringReport, details: ["ownerId": ownerId])
            }

            if shouldBlockUser {
                NotificationCenter.default.post(
                    name: .homeFeedLocallyRemove,
                    object: nil,
                    userInfo: [SpotHomeFeedNotification.authorUserIdKey: ownerId]
                )
            } else {
                NotificationCenter.default.post(
                    name: .homeFeedLocallyRemove,
                    object: nil,
                    userInfo: [SpotHomeFeedNotification.spotIdKey: spotId]
                )
            }

            SpotLogger.log(ReportSheetLogs.reportSubmitted, details: ["spotId": spotId, "reason": reason.rawValue, "blocked": shouldBlockUser])
            isSubmitting = false
            showSuccessMessage = true

        } catch {
            SpotLogger.log(ReportSheetLogs.submitFailed, details: ["error": error.localizedDescription])
            isSubmitting = false
            showSubmitError = true
        }
    }
}
