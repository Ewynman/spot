//
//  SpotsGridView.swift
//  Spot
//
//  Created by Edward Wynman on 8/6/25.
//

import SwiftUI

struct SpotsGridView: View {
    let spots: [Spot]
    let onSpotTapped: (Spot) -> Void
    var onLoadMore: (() -> Void)?
    var columns: Int = 2 // Default to 2 columns for backward compatibility

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(spots) { spot in
                    Button {
                        onSpotTapped(spot)
                    } label: {
                        SpotGridItem(spot: spot, columns: columns)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            if let onLoadMore {
                GeometryReader { _ in
                    Color.clear
                        .onAppear {
                            // Prefetch when bottom sentinel appears
                            onLoadMore()
                        }
                }
                .frame(height: 1)
            }
        }
    }
}

#Preview {
    let spots = [
        Spot(id: "1", userId: "u1", username: "a", imageURL: "https://picsum.photos/seed/p1/600/600", vibeTag: "Park", latitude: 0, longitude: 0, locationName: "NYC", createdAt: Date()),
        Spot(id: "2", userId: "u1", username: "a", imageURL: "https://picsum.photos/seed/p2/600/600", vibeTag: "Cafe", latitude: 0, longitude: 0, locationName: "LA", createdAt: Date())
    ]
    return SpotsGridView(spots: spots, onSpotTapped: { _ in })
}

struct SpotGridItem: View {
    let spot: Spot
    let columns: Int

    private var itemWidth: CGFloat {
        SpotGridLayout.itemWidth(columns: columns, containerWidth: UIScreen.main.bounds.width)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageURL = spot.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { img in
                    img.resizable()
                       .scaledToFill()
                       .frame(width: itemWidth, height: itemWidth)
                       .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: itemWidth, height: itemWidth)
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: itemWidth, height: itemWidth)
            }

            if let location = spot.locationName {
                Text(location)
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Constants.Colors.primary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
