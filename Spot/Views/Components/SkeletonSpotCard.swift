//
//  SkeletonSpotCard.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct SkeletonSpotCard: View {
    @State private var phase: CGFloat = 0

    private var skeletonMediaHeight: CGFloat {
        let w = SpotMediaAspectRatio.estimatedFeedContentWidth()
        return SpotMediaAspectRatio.mediaHeight(
            containerWidth: w,
            displayRatio: SpotMediaAspectRatio.fallbackRatio,
            minHeight: SpotMediaPresentationContext.feed.minMediaHeight,
            maxHeight: SpotMediaPresentationContext.feed.maxMediaHeight
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 6).fill(shimmer).frame(width: 210, height: 22)
                RoundedRectangle(cornerRadius: 6).fill(shimmer).frame(width: 125, height: 14)
                RoundedRectangle(cornerRadius: 10).fill(shimmer).frame(width: 80, height: 24)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(shimmer)
                .frame(maxWidth: .infinity)
                .frame(height: skeletonMediaHeight)

            HStack(spacing: 8) {
                Circle().fill(shimmer).frame(width: 32, height: 32)
                RoundedRectangle(cornerRadius: 6).fill(shimmer).frame(width: 150, height: 14)
                Spacer()
            }

            HStack {
                RoundedRectangle(cornerRadius: 8).fill(shimmer).frame(width: 18, height: 18)
                Spacer()
                RoundedRectangle(cornerRadius: 8).fill(shimmer).frame(width: 18, height: 18)
                Spacer()
                RoundedRectangle(cornerRadius: 8).fill(shimmer).frame(width: 18, height: 18)
            }
            .frame(height: 44)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Constants.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Constants.Colors.primary.opacity(0.08), radius: 8, y: 3)
        .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 } }
    }

    private var shimmer: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.35), Color.gray.opacity(0.25)]), startPoint: .leading, endPoint: .trailing)
    }
}

#Preview {
    SkeletonSpotCard()
        .padding()
        .background(Color(hex: "F5F3EF"))
}
