import SwiftUI

enum SpotLoadingSkeleton {
    static let shimmerFill = LinearGradient(
        gradient: Gradient(colors: [
            Color.gray.opacity(0.25),
            Color.gray.opacity(0.35),
            Color.gray.opacity(0.25),
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// Square tile placeholders matching `SpotsGridView` / `SpotGridItem` width math (embed in a `ScrollView` if needed).
struct SpotGridSkeletonCells: View {
    let columns: Int
    let cellCount: Int

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    private var tileSide: CGFloat {
        SpotGridLayout.itemWidth(columns: columns, containerWidth: UIScreen.main.bounds.width)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(0..<cellCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(SpotLoadingSkeleton.shimmerFill)
                    .frame(height: tileSide)
            }
        }
    }
}

/// Full-screen scroll placeholder for likes, bookmarks, and collection spot grids (`SpotsGridView` defaults to 3 columns there).
struct SpotGridLoadingPlaceholder: View {
    var columns: Int = 3
    var cellCount: Int = 9

    var body: some View {
        ScrollView {
            SpotGridSkeletonCells(columns: columns, cellCount: cellCount)
                .padding(.horizontal, 12)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Two-column collection cards while Pro bookmarks collections load (`CollectionCardView` sizing).
struct BookmarksCollectionsLoadingPlaceholder: View {
    private let placeholderCount = 6
    private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var cardWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 12 * 2
        let spacing: CGFloat = 12
        return (screenWidth - padding - spacing) / 2
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(0..<placeholderCount, id: \.self) { _ in
                    BookmarkCollectionCardSkeleton(itemWidth: cardWidth)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BookmarkCollectionCardSkeleton: View {
    let itemWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(SpotLoadingSkeleton.shimmerFill)
                .frame(width: itemWidth, height: itemWidth)

            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(SpotLoadingSkeleton.shimmerFill)
                    .frame(width: min(120, itemWidth * 0.55), height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(SpotLoadingSkeleton.shimmerFill)
                    .frame(width: 22, height: 12)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(width: itemWidth)
            .background(Color.white.opacity(0.95))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Constants.Colors.primary, lineWidth: 1)
        )
    }
}

#Preview("Grid 3") {
    SpotGridLoadingPlaceholder()
        .background(Color(hex: "F5F3EF"))
}

#Preview("Collections") {
    BookmarksCollectionsLoadingPlaceholder()
        .background(Constants.Colors.background)
}
