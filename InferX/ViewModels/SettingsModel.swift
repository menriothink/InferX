//
//  SettingsViewModel.swift
//  InferX
//
//  Created by mingdw on 2025/3/7.
//

import SwiftUI
import os
import SwiftData
import Defaults
import MarkdownUI

let enableDebugLog = true

let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.InferX.app", category: "")

private let logDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
}()

enum LogLevel {
    case info, debug, error
}

func timestampedLogger(_ message: String, level: LogLevel = .info) {
    let timestamp = logDateFormatter.string(from: Date())
    let fullMessage = "[\(timestamp)] \(message)"
    switch level {
    case .info:
        logger.info("\(fullMessage)")
    case .debug:
        if enableDebugLog {
            logger.debug("\(fullMessage)")
        }
    case .error:
        logger.error("\(fullMessage)")
    }
}

@MainActor
@Observable
final class SettingsModel {
    enum SidebarState {
        case left
        case right
        case none
    }
    var sidebarState: SidebarState = .none

    enum SidebarItemID: String, Identifiable {
        case conversation = "Conversation"
        case modelAPIManager = "Model API Manager"

        var id: String { rawValue }
    }

    var selectedItem: SidebarItemID = .conversation

    var isFixSize = false

    var error: Error?
    var errorTitle: String?
    var showErrorAlert = false

    func throwError(_ error: Error, title: String? = nil) {
        logger.error("\(error.localizedDescription)")
        self.error = error
        errorTitle = title
        showErrorAlert = true
    }
}

enum AppColorScheme: String, CaseIterable, Identifiable, Sendable, Defaults.Serializable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { self.rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum FontWeightOption: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    case heavy = "Heavy"
    case black = "Black"

    var id: String { self.rawValue }

    var actualWeight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }

    var displayName: String {
        switch self {
        case .light: return "细体 (Light)"
        case .regular: return "常规 (Regular)"
        case .medium: return "中等 (Medium)"
        case .semibold: return "半粗 (Semibold)"
        case .bold: return "粗体 (Bold)"
        case .heavy: return "特粗 (Heavy)"
        case .black: return "黑体 (Black)"
        }
    }

    var weightHtml: String {
        switch self {
            case .light: return "300"
            case .regular: return "400"
            case .medium: return "500"
            case .semibold: return "600"
            case .bold: return "700"
            case .heavy: return "800"
            case .black: return "900"
        }
    }
}
