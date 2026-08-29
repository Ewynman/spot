//
//  PostingRulesView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct PostingRulesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showConfirmSheet = false
    @State private var toast: String?
    var onAgree: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Constants.Colors.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Posting Guidelines")
                            .font(FontManager.sectionHeader())
                            .foregroundColor(Constants.Colors.primary)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Constants.Colors.primary)
                                .padding(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Rules
                    VStack(alignment: .leading, spacing: 10) {
                        ruleRow(text: "It must be a real Spot others can visit")
                        ruleRow(text: "No selfies or faces")
                        ruleRow(text: "No nudity or sexual content")
                        ruleRow(text: "No screenshots, memes, or AI images")
                        ruleRow(text: "One photo per Spot — keep it authentic")
                        ruleRow(text: "Respect privacy and safety; no trespassing")
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Actions
                    VStack(spacing: 12) {
                        if authVM.isEmailVerified {
                            Button(action: { onAgree?() }) {
                                Text("I Understand")
                                    .font(FontManager.buttonText())
                                    .foregroundColor(Constants.Colors.buttonText)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Constants.Colors.primary)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Button(action: { showConfirmSheet = true }) {
                                Text("Verify Email")
                                    .font(FontManager.buttonText())
                                    .foregroundColor(Constants.Colors.buttonText)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Constants.Colors.primary)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Button(action: { dismiss() }) {
                            Text("Close")
                                .font(FontManager.buttonText())
                                .foregroundColor(Constants.Colors.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Constants.Colors.primary, lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                // Toast
                if let message = toast {
                    VStack {
                        ToastView(message: message, isError: false)
                            .transition(.move(edge: .top))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation { toast = nil }
                                }
                            }
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showConfirmSheet) {
            ConfirmEmailView()
        }
    }

    private func ruleRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill").foregroundColor(Constants.Colors.primary)
            Text(text)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    PostingRulesView()
}
