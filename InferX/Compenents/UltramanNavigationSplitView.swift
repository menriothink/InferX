//
//  Untitled 2.swift
//  InferX
//
//  Created by mingdw on 2025/3/8.
//

import SwiftUI

struct UltramanNavigationTitleKey: @preconcurrency PreferenceKey {
    @MainActor static let defaultValue: LocalizedStringKey = ""

    static func reduce(
        value: inout LocalizedStringKey, nextValue: () -> LocalizedStringKey
    ) {
        value = nextValue()
    }
}

struct UltramanToolbarItem: Identifiable, Equatable {
    static func == (lhs: UltramanToolbarItem, rhs: UltramanToolbarItem) -> Bool {
        lhs.id == rhs.id && lhs.alignment == rhs.alignment
    }

    let id = UUID()
    let content: AnyView
    let alignment: ToolbarAlignment

    enum ToolbarAlignment {
        case leading, trailing
    }

    init(alignment: ToolbarAlignment = .trailing, @ViewBuilder content: () -> some View) {
        self.content = AnyView(content())
        self.alignment = alignment
    }
}

struct UltramanNavigationToolbarKey: @preconcurrency PreferenceKey {
    @MainActor static var defaultValue: [UltramanToolbarItem] = []

    static func reduce(
        value: inout [UltramanToolbarItem],
        nextValue: () -> [UltramanToolbarItem]
    ) {
        let newItems = nextValue()
        if !newItems.isEmpty {
            value.append(contentsOf: newItems)
        }
    }
}

@resultBuilder
struct UltramanToolbarBuilder {
    static func buildBlock(_ components: UltramanToolbarItem...) -> [UltramanToolbarItem] {
        components
    }
}

extension View {
    func ultramanNavigationTitle(_ title: LocalizedStringKey) -> some View {
        preference(key: UltramanNavigationTitleKey.self, value: title)
    }

    func ultramanToolbar(
        alignment: UltramanToolbarItem.ToolbarAlignment = .trailing,
        @ViewBuilder content: () -> some View
    ) -> some View {
        preference(
            key: UltramanNavigationToolbarKey.self,
            value: [
                UltramanToolbarItem(
                    alignment: alignment,
                    content: {
                        content()
                    })
            ]
        )
    }

    func ultramanToolbar(
        @UltramanToolbarBuilder content: () -> [UltramanToolbarItem]
    ) -> some View {
        preference(
            key: UltramanNavigationToolbarKey.self,
            value: content()
        )
    }
}

struct UltramanNavigationSplitView<Sidebar: View, Detail: View>: View {
    @State var sidebarWidth: CGFloat = 250
    @State private var lastNonZeroWidth: CGFloat = 250
    let sidebar: () -> Sidebar
    let detail: () -> Detail

    @State private var navigationTitle: LocalizedStringKey = ""
    @State private var toolbarItems: [UltramanToolbarItem] = []

    @State private var isDragging = false
    @State private var isSidebarVisible = false

    let minSidebarWidth: CGFloat = 200
    let maxSidebarWidth: CGFloat = 400

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .leading) {
                Color.primary.opacity(0.0001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isSidebarVisible = false
                        }
                    }

                if isSidebarVisible {
                    sidebar()
                        .frame(width: sidebarWidth)
                        .transition(.move(edge: .leading))
                }

                VStack(spacing: .zero) {
                    Divider()
                    detail()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onPreferenceChange(UltramanNavigationTitleKey.self) { newTitle in
                            Task { @MainActor in
                                navigationTitle = newTitle
                            }
                        }
                        .onPreferenceChange(UltramanNavigationToolbarKey.self) { newItems in
                            Task { @MainActor in
                                toolbarItems = newItems
                            }
                        }
                }

                .safeAreaInset(edge: .top, alignment: .center, spacing: 0) {
                    if isSidebarVisible {
                        HStack(alignment: .bottom) {
                            Spacer()
                                .padding()
                            header()
                                .frame(height: 52)
                                .frame(alignment: .leading)
                            Spacer()
                                .padding()
                        }
                    }
                    else {
                        header().frame(height: 52)
                    }
                }
            }
        }
    }

    @MainActor
    @ViewBuilder
    func header() -> some View {
        VStack(spacing: 0) {
            Spacer()

            HStack {
                if !isSidebarVisible {
                    Spacer()
                        .frame(width: 80)
                }

                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .buttonStyle(.plain)

                ForEach(toolbarItems.filter { $0.alignment == .leading }) {
                    item in
                    item.content
                }

                Spacer()
                Text(navigationTitle)
                    .font(.headline)

                Spacer()

                ForEach(toolbarItems.filter { $0.alignment == .trailing }) {
                    item in
                    item.content
                }
            }
            .padding(.horizontal, 10)
            .padding(.trailing, 5)
            Spacer()
        }
        .frame(height: 50)
        .foregroundColor(.primary)
    }

    func toggleSidebar() {
        withAnimation {
            if isSidebarVisible {
                lastNonZeroWidth = sidebarWidth
                sidebarWidth = 0
            } else {
                sidebarWidth = lastNonZeroWidth
            }
            isSidebarVisible.toggle()
        }
    }
}
