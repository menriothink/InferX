//
//  EffectView.swift
//  InferX
//
//  Created by mingdw on 2025/5/6.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(macOS)
import AppKit

/// A SwiftUI Wrapper for `NSVisualEffectView`
///
/// ## Usage
/// ```swift
/// EffectView(material: .headerView, blendingMode: .withinWindow)
/// ```
struct EffectView: NSViewRepresentable {
    private let material: NSVisualEffectView.Material
    private let blendingMode: NSVisualEffectView.BlendingMode
    private let emphasized: Bool

    init(
        _ material: NSVisualEffectView.Material = .headerView,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        emphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.emphasized = emphasized

    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = emphasized
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }

    @ViewBuilder
    static func selectionBackground(_ condition: Bool = true) -> some View {
        if condition {
            EffectView(.selection, blendingMode: .withinWindow, emphasized: true)
        } else {
            Color.clear
        }
    }
}

#else

/// iOS-compatible blur effect wrapper mirroring the macOS API surface
struct EffectView: View {
    private let style: UIBlurEffect.Style

    init(
        _ material: UIBlurEffect.Style = .systemMaterial,
        blendingMode: UIBlurEffect.Style = .systemMaterial, // kept for signature compatibility
        emphasized: Bool = false
    ) {
        self.style = emphasized ? .systemThinMaterial : material
    }

    var body: some View {
        VisualEffectBlur(blurStyle: style)
    }

    @ViewBuilder
    static func selectionBackground(_ condition: Bool = true) -> some View {
        if condition {
            EffectView(.systemMaterial, emphasized: true)
        } else {
            Color.clear
        }
    }
}

/// Lightweight UIKit blur wrapper for SwiftUI
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

#endif
