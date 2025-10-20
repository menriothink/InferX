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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsModel)
                .environment(
                    \.locale, .init(identifier: language.rawValue)
                )
                .preferredColorScheme(appColorScheme == .system ? nil : appColorScheme.colorScheme)
                .modelContainer(SwiftDataProvider.share.container)
                .ultramanMinimalistWindowStyle()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)

        Window("Settings", id: "Settings") {
            SettingsView()
                .environment(settingsModel)
                .preferredColorScheme(appColorScheme == .system ? nil : appColorScheme.colorScheme)
                .frame(minWidth: 400, idealWidth: 400, maxWidth: .infinity, minHeight: 720, idealHeight: 720, maxHeight: .infinity)
                .ultramanMinimalistWindowStyle()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
