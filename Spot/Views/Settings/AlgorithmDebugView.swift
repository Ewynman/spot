//
//  AlgorithmDebugView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct AlgorithmDebugView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var prettyJSON: String = ""
    @State private var profileVersion: Int?
    @State private var lastComputedAt: Date?
    @State private var isLoading: Bool = false
    @State private var isRecomputing: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    actionsCard
                    snapshotCard
                }
                .padding(16)
            }
        }
        .background(Color(hex: "F5F3EF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task { await load() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
            }
            .buttonStyle(PlainButtonStyle())

            Text("Algorithm snapshot")
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)
                .frame(maxWidth: .infinity)

            Spacer().frame(width: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Cards

    private var headerCard: some View {
        debugCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("user_feed_profiles")
                    .font(FontManager.sectionHeader())
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.primary)

                Text("This is the cached personalization snapshot used by the iOS client. The cron job (`feed-profiles-recompute-3h`) refreshes it every ~3h. You can also force a recompute below.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    metaRow(
                        label: "Version",
                        value: profileVersion.map { "\($0)" } ?? "—"
                    )
                    metaRow(
                        label: "Last computed",
                        value: lastComputedAt.map { Self.timestampFormatter.string(from: $0) } ?? "—"
                    )
                }
                .padding(.top, 4)
            }
        }
    }

    private var actionsCard: some View {
        debugCard {
            VStack(spacing: 12) {
                Button {
                    Task { await recompute() }
                } label: {
                    HStack {
                        if isRecomputing {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRecomputing ? "Recomputing…" : "Recompute now")
                            .font(FontManager.buttonText())
                    }
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.Colors.primary)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isRecomputing)

                Button {
                    UIPasteboard.general.string = prettyJSON
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy JSON to clipboard")
                            .font(FontManager.buttonText())
                    }
                    .foregroundColor(Constants.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "F5F3EF"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Constants.Colors.primary, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(prettyJSON.isEmpty)
            }
        }
    }

    private var snapshotCard: some View {
        debugCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Raw JSON")
                    .font(FontManager.sectionHeader())
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.primary)

                if isLoading && prettyJSON.isEmpty {
                    HStack { ProgressView(); Text("Loading…").foregroundColor(.gray) }
                        .padding(.vertical, 12)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if prettyJSON.isEmpty {
                    Text("No row yet. Try Recompute.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(prettyJSON)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(Constants.Colors.primary)
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "F5F3EF"))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Sub-components

    private func metaRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Constants.Colors.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func debugCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let data = try await FeedAPI.getMyFeedProfileRawData()
            applyRawData(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recompute() async {
        if isRecomputing { return }
        isRecomputing = true
        errorMessage = nil
        defer { isRecomputing = false }
        do {
            _ = try await FeedAPI.recomputeMyFeedProfile()
            let data = try await FeedAPI.getMyFeedProfileRawData()
            applyRawData(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyRawData(_ data: Data) {
        let snapshot = FeedProfileSnapshotParser.parse(data)
        profileVersion = snapshot.profileVersion
        lastComputedAt = snapshot.lastComputedAt
        prettyJSON = snapshot.prettyJSON
    }

    // MARK: - Formatters

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

#Preview {
    NavigationStack { AlgorithmDebugView() }
}
