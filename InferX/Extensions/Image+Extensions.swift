//
//  Image+Extensions.swift
//  InferX
//
//  Created by mingdw on 2025/9/16.
//

import SwiftUI

public enum ImageFormat {
    case png
    case jpeg(compressionQuality: CGFloat = 0.8)
}

extension Image {
    @MainActor
    func toNSImage(size: CGSize) -> NSImage? {
        if #available(macOS 13.0, *) {
            let renderer = ImageRenderer(content: self)
            renderer.proposedSize = ProposedViewSize(size)
            return renderer.nsImage
        } else {
            let hostingController = NSHostingController(rootView: self.frame(width: size.width, height: size.height))
            let view = hostingController.view
            view.frame = CGRect(origin: .zero, size: size)

            guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                return nil
            }

            view.cacheDisplay(in: view.bounds, to: bitmapRep)
            
            let nsImage = NSImage(size: size)
            nsImage.addRepresentation(bitmapRep)
            
            return nsImage
        }
    }
    
    init?(data: Data?) {
        guard let data else { return nil }
        #if canImport(AppKit) || canImport(UIKit)
        if let platformImage = PlatformImage(data: data) {
            #if canImport(AppKit)
            self.init(nsImage: platformImage)
            #elseif canImport(UIKit)
            self.init(uiImage: platformImage)
            #endif
        } else {
            return nil
        }
        #else
        return nil
        #endif
    }
        
    @MainActor
    func toData(size: CGSize, format: ImageFormat = .png) -> Data? {
        let viewToRender = self
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let hostingController = NSHostingController(rootView: viewToRender)
        hostingController.view.frame = CGRect(origin: .zero, size: size)

        guard let bitmapRep = hostingController.view.bitmapImageRepForCachingDisplay(in: hostingController.view.bounds) else {
            return nil
        }
        
        hostingController.view.cacheDisplay(in: hostingController.view.bounds, to: bitmapRep)
        
        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .jpeg(let quality):
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        }
        
        #elseif canImport(UIKit)
        let renderer = ImageRenderer(content: viewToRender)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = PlatformImage().scale
        
        guard let platformImage = renderer.platformImage else { return nil }
        
        switch format {
        case .png:
            return platformImage.pngData()
        case .jpeg(let quality):
            return platformImage.jpegData(compressionQuality: quality)
        }
        
        #else
        return nil
        #endif
    }
}

#if canImport(UIKit)
// iOS 16.0+, macOS 13.0+
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private extension ImageRenderer {
    var platformImage: PlatformImage? {
        #if canImport(UIKit)
        return self.uiImage
        #elseif canImport(AppKit)
        return self.nsImage
        #else
        return nil
        #endif
    }
}
#endif
