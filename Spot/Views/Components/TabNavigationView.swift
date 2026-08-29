//
//  TabNavigationView.swift
//  Spot
//
//  Created by Edward Wynman on 3/2/25.
//

import SwiftUI

struct TabNavigationView: View {
    @Binding var selectedTab: String
    let tabs: [String]

    var body: some View {
        HStack(spacing: 32) {
            ForEach(tabs, id: \.self) { tab in
                TabItemView(tab: tab, isSelected: selectedTab == tab) {
                    SpotLogger.log(TabNavigationViewLogs.userSwitchedTab, details: ["tab": "\(tab)"])
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color(hex: "F5F3EF"))
    }
}

struct TabItemView: View {
    let tab: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(tab)
                .font(FontManager.primaryText())
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? Constants.Colors.primary : .gray)

            Rectangle()
                .fill(isSelected ? Constants.Colors.primary : Color.clear)
                .frame(height: 2)
        }
        .onTapGesture(perform: onTap)
    }
}
