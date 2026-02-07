//
//  InferXApp.swift
//  InferX
//
//  Created by mingdw on 2025/3/6.
//

import Defaults
import SwiftUI
import SwiftData
import os

@main
struct InferXApp: App {
    @Default(.language) var language
    @Default(.appColorScheme) var appColorScheme
    @State private var settingsModel = SettingsModel()
    
    private var overrideLocale: Locale? {
        switch language {
        case .system:
            return nil
        default:
            return .init(identifier: language.rawValue)
        }
    }
    
    private var overrideLayoutDirection: LayoutDirection? {
        switch language {
        case .system:
            return nil
        case .arabic, .hebrew:
            return .rightToLeft
        default:
            return .leftToRight
        }
    }
    
    @ViewBuilder
    private func applyLocalization<V: View>(_ view: V) -> some View {
        if let overrideLocale {
            view
                .environment(\.locale, overrideLocale)
                .environment(\.layoutDirection, overrideLayoutDirection ?? .leftToRight)
        } else {
            view
        }
    }

    var body: some Scene {
#if os(macOS)
        WindowGroup {
            applyLocalization(
                ContentView()
                    .id(language.rawValue)
                    .environment(settingsModel)
                    .preferredColorScheme(appColorScheme == .system ? nil : appColorScheme.colorScheme)
                    .modelContainer(SwiftDataProvider.share.container)
                    .ultramanMinimalistWindowStyle()
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)

        Window("Settings", id: "Settings") {
            applyLocalization(
                SettingsView()
                    .id(language.rawValue)
                    .environment(settingsModel)
                    .preferredColorScheme(appColorScheme == .system ? nil : appColorScheme.colorScheme)
                    .frame(minWidth: 400, idealWidth: 400, maxWidth: .infinity, minHeight: 720, idealHeight: 720, maxHeight: .infinity)
                    .ultramanMinimalistWindowStyle()
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
#else
        WindowGroup {
            applyLocalization(
                ContentView()
                    .id(language.rawValue)
                    .environment(settingsModel)
                    .preferredColorScheme(appColorScheme == .system ? nil : appColorScheme.colorScheme)
                    .modelContainer(SwiftDataProvider.share.container)
            )
        }
#endif
    }
}
