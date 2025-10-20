//
//  Window+Extensition.swift
//  InferX
//
//  Created by mingdw on 2025/4/5.
//

import AppKit
import Defaults
import SwiftUI
import SwiftUIIntrospect

struct DraggableArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return DraggableNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        nsView.removeFromSuperview()
    }
}

class DraggableNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

@MainActor
struct UltramanMinimalistWindowModifier: ViewModifier {
    @State private var isFullScreen: Bool = false

    func body(content: Content) -> some View {
        content
            .ignoresSafeArea()
            .background(
                VisualEffectView(
                    material: .fullScreenUI,
                    blendingMode: .behindWindow,
                    state: .active
                )
                .ignoresSafeArea()
            )
            .introspect(.window, on: .macOS(.v14, .v15)) { window in
                window.alphaValue = 1
                window.toolbarStyle = .unified
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden

                NotificationCenter.default.addObserver(
                    forName: NSWindow.didEnterFullScreenNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    Task { @MainActor in
                        self.isFullScreen = true
                        self.updateFullScreenSettings(for: window)
                    }
                }

                NotificationCenter.default.addObserver(
                    forName: NSWindow.didExitFullScreenNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    Task { @MainActor in
                        self.isFullScreen = false
                        self.updateFullScreenSettings(for: window)
                    }
                }
            }
    }

    private func updateFullScreenSettings(for window: NSWindow) {
        if isFullScreen {
            window.collectionBehavior.insert(.fullScreenPrimary)
            window.toolbar?.isVisible = false
            NSApp.presentationOptions = [
                .autoHideToolbar,
                .autoHideMenuBar,
                .fullScreen
            ]
        } else {
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.toolbar?.isVisible = true
            NSApp.presentationOptions = []
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = state
        visualEffectView.wantsLayer = true
        visualEffectView.isEmphasized = true
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

extension View {
    func ultramanMinimalistWindowStyle() -> some View {
        modifier(UltramanMinimalistWindowModifier())
    }
}
