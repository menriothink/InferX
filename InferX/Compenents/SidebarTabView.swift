//
//  SidebarTabView.swift
//  InferX
//
//  Created by mingdw on 2025/5/17.
//

import SwiftUI

struct SidebarTabView<T: Hashable & Equatable>: Identifiable, Equatable {
    static func == (lhs: SidebarTabView<T>, rhs: SidebarTabView<T>) -> Bool {
        lhs.id == rhs.id && lhs.icon == rhs.icon
    }

    let id: T
    let icon: Image
    let iconSize: CGFloat

    init(_ id: T, _ icon: Image, _ iconSize: CGFloat = 35) {
        self.id = id
        self.icon = icon
        self.iconSize = iconSize
    }

    func iconView() -> some View {
        Rectangle()
            .opacity(0)
            .overlay {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .shadow(radius: 4)
            }
            .aspectRatio(1, contentMode: .fit)
            .fixedSize()
    }
}
