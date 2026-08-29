//
//  EmptyFeedView.swift
//  Spot
//
//  Created by Edward Wynman on 3/2/25.
//

import SwiftUI

struct EmptyFeedView: View {
    /// Status code from `get_home_feed_status_v1`. Default mirrors the legacy
    /// "no spots" copy.
    var status: String = "no_eligible_spots"
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(title)
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(FontManager.primaryText())
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let onRetry {
                Button(action: onRetry) {
                    Text("Refresh")
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Constants.Colors.primary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .background(Color(hex: "F5F3EF"))
    }

    private var iconName: String {
        switch status {
        case "caught_up":
            return "checkmark.circle"
        case "no_eligible_spots":
            return "person.2.slash"
        case "no_spots_global":
            return "photo.on.rectangle.angled"
        default:
            return "photo.on.rectangle.angled"
        }
    }

    private var title: String {
        switch status {
        case "caught_up":
            return "You're all caught up"
        case "no_eligible_spots":
            return "Nothing to show yet"
        case "no_spots_global":
            return "No Spots Yet"
        default:
            return "No Spots Yet"
        }
    }

    private var subtitle: String {
        switch status {
        case "caught_up":
            return "Pull to refresh, or follow more people to keep your feed fresh."
        case "no_eligible_spots":
            return "Follow more people, unblock users, or change your filters to see spots."
        case "no_spots_global":
            return "Be the first to post a spot!"
        default:
            return "Follow people to see their spots!"
        }
    }
}

#Preview("Caught up") {
    EmptyFeedView(status: "caught_up", onRetry: {})
}

#Preview("No eligible") {
    EmptyFeedView(status: "no_eligible_spots", onRetry: {})
}
