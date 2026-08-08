import SwiftUI

struct PaywallView: View {
    /// Called after a purchase or restore grants Pro (sheet dismisses first; use for follow-up UI such as onboarding).
    var onProUnlocked: (() -> Void)? = nil

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var priceLine = ""
    @State private var purchaseError: String?
    /// `true` while the initial StoreKit `Product.products(for:)` request is
    /// in flight. Combined with `productLoadFailed` we can render a
    /// retryable error state instead of an indefinite "Loading…" string —
    /// Apple App Review (Guideline 2.1(b)) explicitly flagged the previous
    /// stuck-on-loading paywall.
    @State private var isLoadingProduct: Bool = false

    private var isStoreBusy: Bool {
        PaywallPurchaseUIState.isStoreBusy(
            isPurchasing: subscriptionManager.isPurchasing,
            isRestoring: subscriptionManager.isRestoring
        )
    }

    private var isPurchaseDisabled: Bool {
        PaywallPurchaseUIState.isPurchaseDisabled(
            isStoreBusy: isStoreBusy,
            hasProduct: subscriptionManager.hasProduct
        )
    }

    private var productLoadFailed: Bool {
        PaywallPurchaseUIState.productLoadFailed(
            isLoadingProduct: isLoadingProduct,
            hasProduct: subscriptionManager.hasProduct
        )
    }

    private var primaryButtonTitle: String {
        PaywallPurchaseUIState.primaryButtonTitle(
            isPurchasing: subscriptionManager.isPurchasing,
            isRestoring: subscriptionManager.isRestoring,
            priceLine: priceLine
        )
    }

    /// Status line shown under the plan name. Three exclusive states:
    ///   1. loading  → "Loading subscription details…"
    ///   2. error    → user-facing copy from `SubscriptionManager`
    ///   3. loaded   → localized price (`priceLine`)
    /// We never sit indefinitely on (1).
    private var priceOrStatusLine: String {
        PaywallPurchaseUIState.priceOrStatusLine(
            isLoadingProduct: isLoadingProduct,
            priceLine: priceLine
        )
    }

    private var productLoadMessage: String? {
        PaywallPurchaseUIState.productLoadMessage(productLoadFailed: productLoadFailed)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Go Pro")
                        .font(FontManager.sectionHeader())
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("Spot Pro")
                                .font(FontManager.primaryText())
                                .fontWeight(.semibold)
                                .foregroundColor(Constants.Colors.primary)

                            Text("•")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text("Yearly auto-renewable subscription")
                                .font(FontManager.primaryText())
                                .fontWeight(.semibold)
                                .foregroundColor(Constants.Colors.primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }

                        if !priceOrStatusLine.isEmpty {
                            Text(priceOrStatusLine)
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                                .accessibilityIdentifier("paywall.priceLine")
                        }

                        if let productLoadMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(productLoadMessage)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button(action: { Task { await retryProductLoad() } }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Try Again")
                                            .font(FontManager.primaryText())
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(Constants.Colors.buttonText)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Constants.Colors.primary)
                                    .cornerRadius(20)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityIdentifier("paywall.tryAgainButton")
                            }
                        }

                        Divider()

                        Text("Includes Pro features while your subscription is active:")
                            .font(FontManager.primaryText())
                            .fontWeight(.semibold)
                            .foregroundColor(Constants.Colors.primary)

                        Group {
                            FeatureRow(title: "Custom vibe tags")
                            FeatureRow(title: "Up to 5 images per spot")
                            FeatureRow(title: "Edit spots after posting")
                            FeatureRow(title: "Unlimited bookmarks")
                            FeatureRow(title: "Collections for bookmarks")
                            FeatureRow(title: "Advanced search filters")
                            FeatureRow(title: "Supporter badge")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Constants.Colors.background)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Constants.Colors.primary, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)

                    Spacer()

                    VStack(spacing: 10) {
                        VStack(spacing: 8) {
                            Text("• Payment will be charged to your iTunes Account at confirmation of purchase")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("• Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("• Your account will be charged for renewal within 24 hours prior to the end of the current period")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("• Subscriptions may be managed and auto-renewal may be turned off by going to your Account Settings after purchase")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 20)

                        HStack(spacing: 10) {
                            Button("Terms of Use (EULA)") {
                                openURL(Constants.Legal.termsURL)
                            }
                            .accessibilityIdentifier("paywall.termsLink")
                            .buttonStyle(.plain)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Constants.Colors.primary)

                            Text("•")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Button("Privacy Policy") {
                                openURL(Constants.Legal.privacyURL)
                            }
                            .accessibilityIdentifier("paywall.privacyLink")
                            .buttonStyle(.plain)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Constants.Colors.primary)
                        }

                        Button(action: subscribe) {
                            Text(primaryButtonTitle)
                                .font(FontManager.buttonText())
                                .foregroundColor(Constants.Colors.buttonText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Constants.Colors.primary)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchaseDisabled)
                        .opacity(isPurchaseDisabled ? 0.6 : 1)
                        .padding(.top, 8)

                        HStack(spacing: 16) {
                            Button(action: restorePurchases) {
                                Text(subscriptionManager.isRestoring ? "Restoring…" : "Restore Purchases")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Constants.Colors.primary)
                            }
                            .buttonStyle(.plain)
                            .disabled(isStoreBusy)
                            .accessibilityIdentifier("paywall.restorePurchasesButton")
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Button(action: openManageSubscriptions) {
                                Text("Manage")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Constants.Colors.primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("paywall.manageButton")
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Constants.Colors.primary)
                            .frame(width: 44, height: 44)
                            .background(Constants.Colors.background)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbarBackground(Constants.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task { await loadStorePrice() }
            .alert("Purchase", isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )) {
                Button("OK", role: .cancel) { purchaseError = nil }
            } message: {
                Text(purchaseError ?? "")
            }
        }
    }

    @MainActor
    private func loadStorePrice() async {
        isLoadingProduct = true
        await subscriptionManager.ensureProductLoaded()
        defer { isLoadingProduct = false }
        guard subscriptionManager.hasProduct else { return }
        guard let product = try? await subscriptionManager.loadProduct() else { return }
        priceLine = SubscriptionPriceLineFormatter.priceLine(for: product)
    }

    @MainActor
    private func retryProductLoad() async {
        // Clear any prior error/price state so the UI re-enters the
        // "loading" branch instead of flashing the previous failure copy.
        priceLine = ""
        subscriptionManager.resetProductLoadStateForRetry()
        await loadStorePrice()
    }

    private func subscribe() {
        purchaseError = nil
        guard subscriptionManager.hasProduct else {
            purchaseError = SubscriptionManager.userFacingProductLoadError
            return
        }
        guard let appAccountToken = currentAppAccountToken else {
            purchaseError = "Please sign in again before starting Pro."
            return
        }
        SpotLogger.log(PaywallViewLogs.purchaseStarted)
        Task {
            do {
                let outcome = try await subscriptionManager.purchasePro(appAccountToken: appAccountToken)
                switch outcome {
                case .purchased(let expirationDate):
                    // Transaction is already verified via checkVerified in purchasePro().
                    // refreshEntitlement() provides an additional on-device confirmation.
                    var unlocked = false
                    if case .active = await subscriptionManager.refreshEntitlement(for: appAccountToken) {
                        await authVM.setProActive(true, proUntil: expirationDate)
                        unlocked = true
                    }
                    await MainActor.run {
                        dismiss()
                        if unlocked { onProUnlocked?() }
                    }
                case .pending:
                    SpotLogger.log(PaywallViewLogs.purchasePending)
                case .userCancelled:
                    SpotLogger.log(PaywallViewLogs.purchaseCancelled)
                    break
                }
            } catch {
                SpotLogger.log(PaywallViewLogs.purchaseFailed, details: ["error": error.localizedDescription])
                await MainActor.run { purchaseError = error.localizedDescription }
            }
        }
    }

    private func restorePurchases() {
        purchaseError = nil
        guard let appAccountToken = currentAppAccountToken else {
            purchaseError = "Please sign in again before restoring Pro."
            return
        }
        SpotLogger.log(PaywallViewLogs.restoreStarted)
        Task {
            do {
                try await subscriptionManager.restorePurchases()
                switch await subscriptionManager.refreshEntitlement(for: appAccountToken) {
                case .active(let expirationDate):
                    await authVM.setProActive(true, proUntil: expirationDate)
                    await MainActor.run { dismiss() }
                case .linkedToDifferentAccount:
                    await authVM.setProActive(false)
                    await MainActor.run { purchaseError = SubscriptionPurchaseError.subscriptionLinkedToDifferentAccount.localizedDescription }
                case .inactive:
                    await MainActor.run { purchaseError = "No active subscription found." }
                }
            } catch {
                SpotLogger.log(PaywallViewLogs.restoreFailed, details: ["error": error.localizedDescription])
                await MainActor.run { purchaseError = error.localizedDescription }
            }
        }
    }

    private var currentAppAccountToken: UUID? {
        guard let userId = authVM.userId else { return nil }
        return UUID(uuidString: userId)
    }

    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
    
    private func openManageSubscriptions() {
        Task {
            do {
                try await subscriptionManager.manageSubscriptions()
            } catch {
                SpotLogger.log(PaywallViewLogs.manageSubscriptionsFailed, details: ["error": error.localizedDescription])
            }
        }
    }
}

#Preview {
    let auth = AuthViewModel()
    return PaywallView().environmentObject(auth)
}

#Preview("Loaded Yearly Plan") {
    PaywallPreviewCard(priceLine: "$19.99 / year")
        .padding()
        .background(Constants.Colors.background)
}

#Preview("Loading") {
    PaywallPreviewCard(priceLine: "", productLoadMessage: nil)
        .padding()
        .background(Constants.Colors.background)
}

#Preview("Fallback") {
    PaywallPreviewCard(priceLine: "", productLoadMessage: SubscriptionManager.userFacingProductLoadError)
        .padding()
        .background(Constants.Colors.background)
}

#Preview("Already Pro") {
    VStack(spacing: 12) {
        Text("You're Pro")
            .font(FontManager.sectionHeader())
            .foregroundColor(Constants.Colors.primary)
        PaywallPreviewCard(priceLine: "$19.99 / year")
    }
    .padding()
    .background(Constants.Colors.background)
}

#Preview("Small Screen") {
    PaywallPreviewCard(priceLine: "$19.99 / year")
        .padding()
        .frame(width: 375, height: 667)
        .background(Constants.Colors.background)
}

#Preview("Large Screen") {
    PaywallPreviewCard(priceLine: "$19.99 / year")
        .padding()
        .frame(width: 430, height: 932)
        .background(Constants.Colors.background)
}

#Preview("Dark Mode") {
    PaywallPreviewCard(priceLine: "$19.99 / year")
        .padding()
        .background(Constants.Colors.background)
        .preferredColorScheme(.dark)
}

private struct PaywallPreviewCard: View {
    let priceLine: String
    var productLoadMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spot Pro")
                .font(FontManager.primaryText())
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.primary)

            Text(priceLine.isEmpty ? "Loading…" : priceLine)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)

            if let productLoadMessage {
                Text(productLoadMessage)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Divider()
            Group {
                FeatureRow(title: "Custom vibe tags")
                FeatureRow(title: "Up to 5 images per spot")
                FeatureRow(title: "Edit spots after posting")
                FeatureRow(title: "Unlimited bookmarks")
                FeatureRow(title: "Collections for bookmarks")
                FeatureRow(title: "Advanced search filters")
                FeatureRow(title: "Supporter badge")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Constants.Colors.background)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 1))
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
