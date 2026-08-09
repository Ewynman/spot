import SwiftUI

struct SuccessToastView: View {
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Constants.Colors.buttonText)
            Text(message)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.buttonText)
            if let actionTitle, let action {
                Rectangle()
                    .fill(Constants.Colors.buttonText.opacity(0.35))
                    .frame(width: 1, height: 18)
                Button(actionTitle, action: action)
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("toast.action")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Constants.Colors.primary)
        .cornerRadius(20)
        .shadow(radius: 4)
    }
}

#Preview {
    ZStack {
        Color(hex: "F5F3EF").ignoresSafeArea()
        SuccessToastView(message: "Saved")
    }
}
