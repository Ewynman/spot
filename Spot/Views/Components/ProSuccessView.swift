//
//  ProSuccessView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct ProSuccessView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var deepLinkState: DeepLinkState
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Constants.Colors.primary)
            
            // Title
            Text("Welcome to Pro!")
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)
            
            // Message
            Text("Thank you for subscribing! You now have access to all Pro features.")
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Features List
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(title: "Custom vibe tags")
                FeatureRow(title: "Up to 5 images per spot")
                FeatureRow(title: "Edit spots after posting")
                FeatureRow(title: "Unlimited bookmarks")
                FeatureRow(title: "Collections for bookmarks")
                FeatureRow(title: "Advanced search filters")
                FeatureRow(title: "Supporter badge")
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 1))
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                deepLinkState.dismissSubscriptionSuccess()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NotificationCenter.default.post(name: .showPostPurchaseProOnboarding, object: nil)
                }
            }) {
                Text("Continue")
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.Colors.primary)
                    .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Constants.Colors.background.ignoresSafeArea())
    }
}

private struct FeatureRow: View {
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(Constants.Colors.primary)
            Text(title).font(FontManager.primaryText()).foregroundColor(Constants.Colors.primary)
        }
    }
}

#Preview {
    ProSuccessView()
        .environmentObject(AuthViewModel())
        .environmentObject(DeepLinkState.shared)
}
