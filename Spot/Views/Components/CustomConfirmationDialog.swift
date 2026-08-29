//
//  CustomConfirmationDialog.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct CustomConfirmationDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 12) {
                Text(title)
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(FontManager.primaryText())
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text(cancelTitle)
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Constants.Colors.primary.opacity(0.25), lineWidth: 1)
                            )
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .background(Constants.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Constants.Colors.primary.opacity(0.14), lineWidth: 1)
            )
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.15), radius: 16, y: 4)
            .padding(.horizontal, 24)
        }
    }
}
