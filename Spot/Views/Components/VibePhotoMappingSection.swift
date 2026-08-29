//
//  VibePhotoMappingSection.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

/// Toggle + photo→vibe rows for Match Vibes to Photos.
struct VibePhotoMappingSection: View {
    let photos: [(id: UUID, thumbnail: Image)]
    let selectedVibes: [String]
    let canMatch: Bool
    @Binding var matchEnabled: Bool
    let mappings: [UUID: String]
    let statusMessage: String?
    let onToggle: (Bool) -> Void
    let onAssign: (UUID, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.primary.opacity(0.85))
                    .padding(.horizontal, Constants.Layout.Padding.horizontal)
            }

            if canMatch || matchEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { matchEnabled },
                        set: { onToggle($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Match Vibes to Photos")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                            Text("Show a different Vibe with each photo.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(Constants.Colors.primary)
                    .disabled(!canMatch && !matchEnabled)

                    if matchEnabled {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            HStack(spacing: 12) {
                                photo.thumbnail
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipped()
                                    .cornerRadius(10)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Photo \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Menu {
                                        ForEach(selectedVibes, id: \.self) { vibe in
                                            Button(vibe) {
                                                onAssign(photo.id, vibe)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(mappings[photo.id] ?? "Select vibe")
                                                .font(FontManager.primaryText())
                                                .foregroundColor(Constants.Colors.primary)
                                            Spacer(minLength: 4)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Constants.Colors.accent)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Constants.Layout.Padding.horizontal)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("vibePhotoMappingSection")
            }
        }
    }
}
