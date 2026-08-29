//
//  ProfileLoadingPlaceholder.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

/// Skeleton layout while profile data loads (header + Spots/Map tabs + grid), aligned with `SpotsGridView` metrics.
struct ProfileLoadingPlaceholder: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Circle()
                        .fill(SpotLoadingSkeleton.shimmerFill)
                        .frame(width: 100, height: 100)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(SpotLoadingSkeleton.shimmerFill)
                        .frame(width: 160, height: 22)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(SpotLoadingSkeleton.shimmerFill)
                        .frame(width: 132, height: 16)
                }
                .padding(.top, 12)

                HStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SpotLoadingSkeleton.shimmerFill)
                        .frame(width: 52, height: 18)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SpotLoadingSkeleton.shimmerFill)
                        .frame(width: 40, height: 18)
                }

                SpotGridSkeletonCells(columns: 2, cellCount: 6)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ProfileLoadingPlaceholder()
        .background(Constants.Colors.background)
}
