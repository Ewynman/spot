//
//  SpotConfirmationOverlay.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

/// Branded confirmation card used for destructive Spot actions (delete, block).
struct SpotConfirmationOverlay: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let containerAccessibilityIdentifier: String
    let cancelAccessibilityIdentifier: String
    let confirmAccessibilityIdentifier: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 16) {
                Text(title)
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(FontManager.primaryText())
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text(cancelTitle)
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Constants.Colors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Constants.Colors.primary, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(cancelAccessibilityIdentifier)

                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Constants.Colors.primary)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(confirmAccessibilityIdentifier)
                }
            }
            .padding(20)
            .background(Constants.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Constants.Colors.primary.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(containerAccessibilityIdentifier)
    }
}

extension SpotConfirmationOverlay {
    init(
        copy: BlockUserConfirmationCopy,
        containerAccessibilityIdentifier: String,
        cancelAccessibilityIdentifier: String,
        confirmAccessibilityIdentifier: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            title: copy.title,
            message: copy.message,
            confirmTitle: copy.confirmTitle,
            cancelTitle: copy.cancelTitle,
            containerAccessibilityIdentifier: containerAccessibilityIdentifier,
            cancelAccessibilityIdentifier: cancelAccessibilityIdentifier,
            confirmAccessibilityIdentifier: confirmAccessibilityIdentifier,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
}

#Preview("Block user") {
    SpotConfirmationOverlay(
        copy: BlockUserConfirmationCopy.make(username: "eddie"),
        containerAccessibilityIdentifier: "spot.blockConfirmation",
        cancelAccessibilityIdentifier: "spot.blockCancel",
        confirmAccessibilityIdentifier: "spot.blockConfirm",
        onConfirm: {},
        onCancel: {}
    )
}
