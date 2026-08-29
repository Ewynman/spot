//
//  FeedProfileView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct FeedProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FeedProfileViewModel()

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.isLoading && viewModel.row == nil {
                        loadingPlaceholder
                    } else if let profile = viewModel.profile, viewModel.hasContent {
                        freshnessCard(profile: profile)
                        topVibesCard(profile: profile)
                        topCreatorsCard(profile: profile)
                        activityCard(profile: profile)
                        explainerFooter
                    } else if viewModel.profile != nil {
                        emptyState
                    } else if let error = viewModel.errorMessage {
                        errorCard(error)
                    } else {
                        loadingPlaceholder
                    }
                }
                .padding(16)
            }
            .refreshable { await viewModel.recompute() }
        }
        .background(Color(hex: "F5F3EF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.loadInitial() }
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

            Text("Your Algorithm")
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)
                .frame(maxWidth: .infinity)

            Spacer().frame(width: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Cards

    private func freshnessCard(profile: FeedProfile) -> some View {
        algoCard {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Personalized for you")
                        .font(FontManager.primaryText())
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                    Text(freshnessSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Button {
                    Task { await viewModel.recompute() }
                } label: {
                    if viewModel.isRecomputing {
                        ProgressView().scaleEffect(0.8)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Constants.Colors.primary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 36, height: 36)
                .background(Color(hex: "F5F3EF"))
                .clipShape(Circle())
                .disabled(viewModel.isRecomputing)
            }
        }
    }

    private func topVibesCard(profile: FeedProfile) -> some View {
        algoCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader("Your top vibes",
                           subtitle: "What we serve you most often")
                if profile.topVibes.isEmpty {
                    placeholderText("Like or save a few spots and your top vibes will show up here.")
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(profile.topVibes.prefix(8))) { vibe in
                                vibePill(vibe)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func topCreatorsCard(profile: FeedProfile) -> some View {
        algoCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader("Creators you love",
                           subtitle: "We boost their spots in your feed")
                if profile.topCreators.isEmpty {
                    placeholderText("Tap into a few creators and they'll start showing up here.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(profile.topCreators.prefix(5))) { creator in
                            creatorRow(creator)
                        }
                    }
                }
            }
        }
    }

    private func activityCard(profile: FeedProfile) -> some View {
        let s = profile.stats
        let summary = profile.eventSummary30d
        return algoCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader("Last 30 days",
                           subtitle: "What you've been up to")
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    statTile(icon: "heart.fill", label: "Likes",
                             value: "\(eventCount("like", in: summary, fallback: s.likesCount))")
                    statTile(icon: "bookmark.fill", label: "Saves",
                             value: "\(eventCount("save", in: summary, fallback: s.savesCount))")
                    statTile(icon: "eye.fill", label: "Spots viewed",
                             value: "\(eventCount("visible_2s", in: summary))")
                    statTile(icon: "clock.fill", label: "Long looks",
                             value: "\(eventCount("long_dwell", in: summary))")
                }

                Divider().padding(.vertical, 4)

                HStack(spacing: 24) {
                    miniStat(label: "Distinct vibes", value: "\(s.distinctVibesEngaged)")
                    miniStat(label: "Distinct creators", value: "\(s.distinctCreatorsEngaged)")
                    Spacer()
                }
            }
        }
    }

    private var explainerFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How this works")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Constants.Colors.primary)
            Text("Your feed is tuned by what you like, save, dwell on, and skip. We refresh this snapshot every few hours; pull down to recompute it now.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var emptyState: some View {
        algoCard {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Constants.Colors.primary)
                Text("Your algorithm is waking up")
                    .font(FontManager.primaryText())
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.primary)
                Text("Like, save, or open a few spots and check back in a bit. We'll learn what you love.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await viewModel.recompute() }
                } label: {
                    Text(viewModel.isRecomputing ? "Recomputing…" : "Recompute now")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Constants.Colors.primary)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isRecomputing)
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    private var loadingPlaceholder: some View {
        algoCard {
            HStack(spacing: 12) {
                ProgressView()
                Text("Loading your algorithm…")
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func errorCard(_ message: String) -> some View {
        algoCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("We couldn't load your algorithm")
                    .font(FontManager.primaryText())
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.primary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Button {
                    Task { await viewModel.loadInitial(force: true) }
                } label: {
                    Text("Try again")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Constants.Colors.primary)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Sub-components

    private func vibePill(_ vibe: FeedProfile.TopVibe) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vibe.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Constants.Colors.buttonText)
                .lineLimit(1)
            Text(scoreLine(positive: vibe.positiveEvents,
                           negative: vibe.negativeEvents))
                .font(.system(size: 11))
                .foregroundColor(Constants.Colors.buttonText.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Constants.Colors.primary)
        .cornerRadius(14)
    }

    private func creatorRow(_ creator: FeedProfile.TopCreator) -> some View {
        HStack(spacing: 12) {
            avatar(for: creator)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Constants.Colors.primary.opacity(0.15), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(creator.username ?? "—")
                        .font(FontManager.primaryText())
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                        .lineLimit(1)
                    if creator.isPro {
                        Text("Pro")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Constants.Colors.buttonText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Constants.Colors.primary)
                            .cornerRadius(6)
                    }
                }
                Text(scoreLine(positive: creator.positiveEvents,
                               negative: creator.negativeEvents))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }

    private func avatar(for creator: FeedProfile.TopCreator) -> some View {
        Group {
            if let urlString = creator.profileImageURL, let url = URL(string: urlString) {
                RemoteImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        avatarFallback
                    @unknown default:
                        avatarFallback
                    }
                }
            } else {
                avatarFallback
            }
        }
    }

    private var avatarFallback: some View {
        ZStack {
            Color(hex: "F5F3EF")
            Image(systemName: "person.fill")
                .font(.system(size: 16))
                .foregroundColor(Constants.Colors.primary.opacity(0.5))
        }
    }

    private func statTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Constants.Colors.primary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Constants.Colors.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "F5F3EF"))
        .cornerRadius(10)
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Constants.Colors.primary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func algoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func cardHeader(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FontManager.sectionHeader())
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Strings

    private var freshnessSubtitle: String {
        if let date = viewModel.lastComputedAt {
            return "Updated \(relativeString(from: date))"
        } else {
            return "Hasn't been computed yet"
        }
    }

    private func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func scoreLine(positive: Int, negative: Int) -> String {
        if negative > 0 {
            return "\(positive) positive · \(negative) negative"
        } else if positive == 1 {
            return "1 positive event"
        } else {
            return "\(positive) positive events"
        }
    }

    private func eventCount(_ type: String, in summary: FeedProfile.EventSummary, fallback: Int? = nil) -> Int {
        if let bucket = summary.byType.first(where: { $0.eventType == type }) {
            return bucket.count
        }
        return fallback ?? 0
    }
}

#Preview {
    NavigationStack {
        FeedProfileView()
            .environmentObject(AuthViewModel())
    }
}
