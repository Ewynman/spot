//
//  LaunchView.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//

import SwiftUI

struct LaunchView: View {
    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            Text("SPOT")
                .font(FontManager.logoTitle())
                .foregroundColor(Constants.Colors.primary)
        }
    }
}

#Preview {
    LaunchView()
}
