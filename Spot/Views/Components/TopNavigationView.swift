//
//  TopNavigationView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct TopNavigationView: View {
    let title: String
    let showBackButton: Bool
    let rightButton: RightButtonType
    @Binding var showUploadView: Bool
    var onPlusTapped: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    enum RightButtonType {
        case none
        case settings
        case plus
    }

    init(
        title: String,
        showBackButton: Bool = false,
        rightButton: RightButtonType = .none,
        showUploadView: Binding<Bool> = .constant(false),
        onPlusTapped: (() -> Void)? = nil
    ) {
        self.title = title
        self.showBackButton = showBackButton
        self.rightButton = rightButton
        self._showUploadView = showUploadView
        self.onPlusTapped = onPlusTapped
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                if showBackButton {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Constants.Colors.primary)
                    }
                }

                Text(title)
                    .font(FontManager.logoTitle())
                    .foregroundColor(Constants.Colors.primary)

                Spacer()

                switch rightButton {
                case .settings:
                    Button(action: {
                        // Handle settings tap
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(Constants.Colors.primary)
                    }
                case .plus:
                    Button(action: {
                        SpotLogger.log(TopNavigationViewLogs.userTappedPostButton)
                        if let onPlusTapped { onPlusTapped() } else { showUploadView = true }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Constants.Colors.buttonText)
                            .frame(width: 40, height: 40)
                            .background(Constants.Colors.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: CoachFramesPrefKey.self, value: [.plusButton: geo.frame(in: .global)])
                        }
                    )
                    .buttonStyle(PlainButtonStyle())
                case .none:
                    EmptyView()
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .background(Color(hex: "F5F3EF"))
    }
}

// MARK: - Previews
#Preview("Homepage") {
    TopNavigationView(
        title: "SPOT",
        rightButton: .plus,
        showUploadView: .constant(false)
    )
}

#Preview("With Back") {
    TopNavigationView(
        title: "Profile",
        showBackButton: true
    )
}

#Preview("With Settings") {
    TopNavigationView(
        title: "Profile",
        rightButton: .settings
    )
}

#Preview("Basic") {
    TopNavigationView(
        title: "Profile"
    )
}
