//
//  CollectionCardView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct CollectionCardView: View {
    let title: String
    let previewURLs: [String]
    var count: Int?

    private var itemWidth: CGFloat {
        SpotGridLayout.itemWidth(columns: 2, containerWidth: UIScreen.main.bounds.width)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            collage

            // Subtle bottom gradient for legibility
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: itemWidth, height: 44)
            .frame(maxHeight: .infinity, alignment: .bottom)

            HStack {
                Text(title)
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                    .lineLimit(1)
                Spacer()
                if let count { Text("\(count)").font(.caption).foregroundColor(.gray) }
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

    @ViewBuilder
    private var collage: some View {
        let urls = previewURLs
        if urls.isEmpty {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: itemWidth, height: itemWidth)
                .overlay(
                    Image(systemName: "folder")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)
                )
        } else if urls.count == 1, let url = URL(string: urls[0]) {
            AsyncImage(url: url) { img in
                img.resizable()
                    .scaledToFill()
                    .frame(width: itemWidth, height: itemWidth)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: itemWidth, height: itemWidth)
            }
        } else if urls.count == 2 {
            HStack(spacing: 0) {
                collageImage(urls[0], w: itemWidth / 2, h: itemWidth)
                collageImage(urls[1], w: itemWidth / 2, h: itemWidth)
            }
            .frame(width: itemWidth, height: itemWidth)
            .clipped()
        } else if urls.count == 3 {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    collageImage(urls[0], w: itemWidth / 2, h: itemWidth / 2)
                    collageImage(urls[1], w: itemWidth / 2, h: itemWidth / 2)
                }
                HStack(spacing: 0) {
                    collageImage(urls[2], w: itemWidth / 2, h: itemWidth / 2)
                    Rectangle().fill(Color.gray.opacity(0.1)).frame(width: itemWidth / 2, height: itemWidth / 2)
                }
            }
            .frame(width: itemWidth, height: itemWidth)
            .clipped()
        } else {
            // 4 or more -> first 4 in 2x2
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    collageImage(urls[0], w: itemWidth / 2, h: itemWidth / 2)
                    collageImage(urls[1], w: itemWidth / 2, h: itemWidth / 2)
                }
                HStack(spacing: 0) {
                    collageImage(urls[2], w: itemWidth / 2, h: itemWidth / 2)
                    collageImage(urls[3], w: itemWidth / 2, h: itemWidth / 2)
                }
            }
            .frame(width: itemWidth, height: itemWidth)
            .clipped()
        }
    }

    private func collageImage(_ urlString: String, w: CGFloat, h: CGFloat) -> some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.15))
                }
            } else {
                Rectangle().fill(Color.gray.opacity(0.15))
            }
        }
        .frame(width: w, height: h)
        .clipped()
    }
}

#Preview {
    VStack(spacing: 12) {
        CollectionCardView(title: "All Bookmarks", previewURLs: [], count: nil)
        CollectionCardView(title: "NYC Trip", previewURLs: ["https://picsum.photos/seed/col1/600/600", "https://picsum.photos/seed/col2/600/600", "https://picsum.photos/seed/col3/600/600"], count: 8)
    }
    .padding()
    .background(Constants.Colors.background)
}
