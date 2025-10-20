//
//  FileManager+Extensions.swift
//  InferX
//
//  Created by mingdw on 2025/9/14.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit
import AVKit
import PDFKit
import CryptoKit
import WebKit
import QuickLookThumbnailing

extension FileManager {
    func getFileSize(for fileURL: URL) -> NSNumber? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return nil
        }

        return fileSize
    }

    func getMimeType(for fileURL: URL) -> String? {
        if #available(macOS 11.0, *) {
            guard let type = UTType(filenameExtension: fileURL.pathExtension) else {
                return nil
            }
            return type.preferredMIMEType
        }
        return nil
    }

    func getThumbnail(from url: URL) async -> Image? {
        if let fileType = UTType(filenameExtension: url.pathExtension) {
            var thumbnail: NSImage?

            switch true {
            case fileType.conforms(to: .image):
                thumbnail = NSImage(contentsOf: url)
            case fileType.conforms(to: .movie):
                thumbnail = await generateVideoThumbnail(for: url)
            case fileType.conforms(to: .audio):
                thumbnail = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Audio file")
            case fileType.conforms(to: .pdf):
                thumbnail = generatePDFThumbnail(for: url)
            case fileType.conforms(to: .sourceCode):
                thumbnail = NSImage(systemSymbolName: "curlybraces", accessibilityDescription: "Code Document")
            case fileType.conforms(to: .text):
                thumbnail = NSImage(systemSymbolName: "doc.plaintext", accessibilityDescription: "Text Document")
            case fileType.conforms(to: .docx):
                thumbnail = await generateWordThumbnail(for: url)
            case fileType.conforms(to: .doc):
                thumbnail = await generateWordThumbnail(for: url)
            default:
                if let pdfThumbnail = generatePDFThumbnail(for: url) {
                    thumbnail = pdfThumbnail
                } else {
                    thumbnail = NSImage(systemSymbolName: "doc", accessibilityDescription: "Document")
                }
            }

            if let thumbnail {
                return Image(nsImage: thumbnail)
            } else {
                print("getThumbnail failed, instead of default thumbnail")
                thumbnail = NSImage(systemSymbolName: "doc", accessibilityDescription: "Document")
                if let thumbnail {
                    return Image(nsImage: thumbnail)
                }
            }
        }

        return nil
    }

    func getThumbnails(from urls: [URL]) async -> [Image] {
        var thumbnails: [Image] = []

        for url in urls {
            if let thumbnail = await getThumbnail(from: url) {
                thumbnails.append(thumbnail)
            }
        }

        return thumbnails
    }

    func generateWordThumbnail(for url: URL) async -> NSImage? {
        if #available(macOS 10.15, *) {
            if let ql = await quickLookThumbnail(for: url, size: CGSize(width: 256, height: 256)) {
                return ql
            }
        }


        if let attr = try? NSAttributedString(
            url: url,
            options: [:],
            documentAttributes: nil
        ) {
            if let rendered = renderAttributedStringToImage(attr, targetSize: CGSize(width: 256, height: 256)) {
                return rendered
            }
        }

        return NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: "Word Document")
    }

    @available(macOS 10.15, *)
    private func quickLookThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        await withCheckedContinuation { cont in
            let request = QLThumbnailGenerator
                .Request(fileAt: url,
                         size: size,
                         scale: NSScreen.main?.backingScaleFactor ?? 2,
                         representationTypes: .all)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, error in
                if let cg = rep?.cgImage {
                    cont.resume(returning: NSImage(cgImage: cg, size: size))
                } else {
                    if let error { print("QuickLook 失败: \(error.localizedDescription)") }
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private func renderAttributedStringToImage(_ attr: NSAttributedString,
                                               targetSize: CGSize) -> NSImage? {
        let image = NSImage(size: targetSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = CGRect(origin: .zero, size: targetSize)
        let textStorage = NSTextStorage(attributedString: attr)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: rect.size)
        textContainer.lineFragmentPadding = 4
        layoutManager.addTextContainer(textContainer)
        layoutManager.drawGlyphs(forGlyphRange: layoutManager.glyphRange(for: textContainer), at: .init(x: 0, y: 0))
        return image
    }

    private func generatePDFThumbnail(for url: URL) -> NSImage? {
        guard let pdfDocument = PDFDocument(url: url) else {
            print("❌ 无法从 URL 初始化 PDFDocument: \(url.path)")
            return nil
        }

        guard let firstPage = pdfDocument.page(at: 0) else {
            print("❌ PDF 文件没有页面: \(url.path)")
            return nil
        }

        _ = firstPage.bounds(for: .mediaBox)
        let thumbnailSize = CGSize(width: 256, height: 256)

        let thumbnailImage = firstPage.thumbnail(of: thumbnailSize, for: .mediaBox)

        return thumbnailImage
    }

    func generateVideoThumbnail(for url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 1, preferredTimescale: 60)

        do {
            let cgImage = try await imageGenerator.image(at: time).image
            return NSImage(cgImage: cgImage, size: .zero)
        } catch {
            print("Failed to generate video thumbnail: \(error)")
            return NSImage(systemSymbolName: "film", accessibilityDescription: "Video file")
        }
    }

    func getSupportedFileTypes() -> [UTType] {
        let staticImageTypes: [UTType] = [.png, .jpeg, .heic, .heif]
        let staticVideoTypes: [UTType] = [.mpeg4Movie, .mpeg, .movie, .avi]
        let staticAudioTypes: [UTType] = [.wav, .mp3, .aiff]

        let staticDocumentTypes: [UTType] = [
            .pdf, .text, .plainText, .html, .xml, .sourceCode, .swiftSource, .javaScript, .rtf,
            .docx,
            .doc,
            //.pptx,
            //.ppt,
            //.xlsx,
            //.xls
        ]

        let dynamicTypes: [UTType] = [
            UTType("org.webm.webp"),
            UTType("public.3gpp"),
            UTType("com.adobe.flash.video"),
            UTType("org.webmproject.webm"),
            UTType("com.microsoft.windows-media-wmv"),
            UTType("public.aac-audio"),
            UTType("net.daringfireball.markdown")
        ].compactMap { $0 }

        let allSupportedTypes = staticImageTypes + staticVideoTypes + staticAudioTypes + staticDocumentTypes + dynamicTypes

        return allSupportedTypes
    }

    func accessFile<T>(from bookmarkData: Data, accessBlock: (URL) throws -> T) -> T? {
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)

            guard let url = FileManager.default.securityAccessFile(url: url) else {
                print("❌ 无法开始对 URL 的安全访问。")
                return nil
            }

            if isStale {
                print("书签已过期，需要更新")
                /*let newBookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                bookmarkData = newBookmarkData*/
            }

            print("🛑 已开始安全访问。")
            defer {
                url.stopAccessingSecurityScopedResource()
                print("🛑 已停止安全访问。")
            }

            return try accessBlock(url)

        } catch {
            print("🚨 解析或访问文件时出错: \(error.localizedDescription)")
            return nil
        }
    }


    func getBookmark(for url: URL) -> Data? {
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            return bookmark
        } catch {
            print("为 URL [\(url.path)] 创建书签失败: \(error)")
            return nil
        }
    }

    func getResolvedURL(from bookmarkData: inout Data) -> URL? {
        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                print("书签已过期，需要更新")
                let newBookmarkData = try resolvedURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                bookmarkData = newBookmarkData
            }

            return resolvedURL

        } catch {
            print("❌ 从书签解析 URL 失败: \(error)")
            return nil
        }
    }

    func updateBookmarkIfExpired(from bookmarkData: Data) -> Data? {
        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                print("书签已过期，需要更新")
                let newBookmarkData = try resolvedURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                return newBookmarkData
            }
            
            return bookmarkData
        } catch {
            print("❌ getNewBookmark, 从书签解析 URL 失败: \(error)")
            return nil
        }
    }

    func isBookmarkValid(_ bookmarkData: Data) -> Bool {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard let url = FileManager.default.securityAccessFile(url: url) else {
                print("❌ 无法开始对 URL 的安全访问。")
                return false
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            return try url.checkResourceIsReachable()
        } catch {
            return false
        }
    }

    private func appContainerURL() -> URL? {
        guard let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let containerURL = appSupportURL.deletingLastPathComponent().deletingLastPathComponent()
        
        return containerURL
    }
    
    func getDefautModelCacheDirURL() -> URL? {
        guard let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            print("Error: Unable to find Application Support directory.")
            return nil
        }
        guard let bundleID = Bundle.main.bundleIdentifier else {
            print("Error: Unable to find app name in bundle.")
                return nil
        }
        let targetDirectoryURL = appSupportURL
                .appendingPathComponent(bundleID, isDirectory: true)
                .appendingPathComponent(".cache", isDirectory: true)
                .appendingPathComponent("huggingface", isDirectory: true)
                .appendingPathComponent("hub", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: targetDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            return targetDirectoryURL
        } catch {
            print("Error creating directory: \(error)")
            return nil
        }
    }
    
    func securityAccessFile(url: URL?) -> URL? {
        guard let url else { return nil }
        
        if let appContainer = FileManager.default.appContainerURL(),
                url.path.hasPrefix(appContainer.path) {
            return url
        }
        
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ 无法开始安全访问。")
            return nil
        }
        
        return url
    }
    
    func openDirectory(at urlToOpen: URL, in urlInSecurity: URL) throws {
        guard urlToOpen.path.hasPrefix(urlInSecurity.path) else {
            throw SimpleError(message: "错误：尝试打开一个未在授权范围内的目录: \(urlToOpen.path)")
        }

        guard let urlInSecurity = FileManager.default.securityAccessFile(url: urlInSecurity) else {
            print("错误：无法激活对根缓存目录 \(urlInSecurity.path) 的访问权限。可能需要用户重新选择目录。")
            return
        }
        

        defer {
            urlInSecurity.stopAccessingSecurityScopedResource()
        }

        print("正在尝试打开文件夹: \(urlToOpen.path)")
        NSWorkspace.shared.open(urlToOpen)
    }
    
    @MainActor
    func openDirectorySelectionPanel(selectedModelDir: URL?) -> URL? {
        let openPanel = NSOpenPanel()
        
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "选择"
        
        if let startingDirectory = selectedModelDir {
            openPanel.directoryURL = startingDirectory
        }
        
        if openPanel.runModal() == .OK {
            return openPanel.url
        }
        
        return nil
    }
    
    func sha256Base64(for url: URL) -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { handle.closeFile() }

            var hasher = SHA256()
            while autoreleasepool(invoking: {
                let chunk = handle.readData(ofLength: 8192)
                if !chunk.isEmpty {
                    hasher.update(data: chunk)
                    return true
                } else {
                    return false
                }
            }) {}

            let digest = hasher.finalize()
            let localHexHash = digest.map { String(format: "%02hhx", $0) }.joined()

            guard let hexHashData = localHexHash.data(using: .utf8) else {
                return nil
            }

            let localBase64Hash = hexHashData.base64EncodedString()

            //print("File \(url) hash: \(localBase64Hash)")

            return localBase64Hash
        } catch {
            print("🚨 无法计算文件 [\(url.path)] 的哈希: \(error)")
            return nil
        }
    }

    @MainActor
    func convertToPDFIfNeeded(from sourceURL: URL) async -> URL? {
        guard let fileType = UTType(filenameExtension: sourceURL.pathExtension.lowercased()) else {
            return nil
        }

        guard isConvertibleDocumentType(fileType) else {
            print("ℹ️ 文件类型 \(fileType.preferredFilenameExtension ?? "未知") 不支持转换为 PDF")
            return nil
        }

        let hash = sha256Base64(for: sourceURL) ?? UUID().uuidString
        let cacheURL = temporaryDirectory.appendingPathComponent("pdf-cache-\(hash.prefix(8)).pdf")

        if fileExists(atPath: cacheURL.path) {
            print("✅ 使用缓存的 PDF: \(cacheURL.lastPathComponent)")
            return cacheURL
        }

        print("⏳ 正在转换 \(sourceURL.lastPathComponent) 为 PDF...")

        if convertNativelyToPDF(sourceURL: sourceURL, pdfURL: cacheURL) {
            return cacheURL
        } else {
            return nil
        }
    }

    private func convertNativelyToPDF(sourceURL: URL, pdfURL: URL) -> Bool {
        do {
            let documentAttributes: AutoreleasingUnsafeMutablePointer<NSDictionary?>? = nil
            let attributedString = try NSAttributedString(
                url: sourceURL,
                options: [:],
                documentAttributes: documentAttributes
            )

            var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 纸尺寸
            guard let context = CGContext(pdfURL as CFURL, mediaBox: &mediaBox, nil) else {
                print("❌ [原生转换] 无法创建 PDF 上下文。")
                return false
            }

            let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
                        
            var currentRange = CFRange(location: 0, length: 0)
            var characterIndex = 0
            let stringLength = attributedString.length

            while characterIndex < stringLength {
                context.beginPDFPage(nil)

                let printableRect = mediaBox.insetBy(dx: 72, dy: 72)
                let path = CGPath(rect: printableRect, transform: nil)

                currentRange = CFRange(location: characterIndex, length: 0)
                let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)

                CTFrameDraw(frame, context)

                let frameRange = CTFrameGetVisibleStringRange(frame)

                characterIndex += frameRange.length

                context.endPDFPage()
            }
            
            context.closePDF()

            print("✅ [原生转换] 成功将 \(sourceURL.lastPathComponent) 转换为 PDF。")
            return true

        } catch {
            print("❌ [原生转换] 失败: \(error.localizedDescription)。")
            return false
        }
    }


    private func CGContext(_ url: CFURL, mediaBox: inout CGRect, _ unused: Any?) -> CGContext? {
        guard let consumer = CGDataConsumer(url: url) else { return nil }
        return CoreGraphics.CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    }

    private func isConvertibleDocumentType(_ fileType: UTType) -> Bool {
        let convertibleTypes: [UTType] = [
            .docx, .doc,         // Word
            //.pptx, .ppt,         // PowerPoint
            //.xlsx, .xls,         // Excel
            .rtf, .rtfd,         // Rich Text
            .text, .plainText,   // Plain Text
            .html, .xml, //.csv    // Web & Data Formats
        ]

        return convertibleTypes.contains { fileType.conforms(to: $0) }
    }

    @MainActor
    private func convertByWebView(sourceURL: URL, pdfURL: URL) async -> Bool {
        print("enter convertByWebView")

        guard let sourceURL = FileManager.default.securityAccessFile(url: sourceURL) else {
            print("❌ convertByWebView: 无法开始对源 URL 的安全访问。")
            return false
        }

        print("🛑 convertByWebView: 已开始对源 URL 的安全访问。")
        defer {
            sourceURL.stopAccessingSecurityScopedResource()
            print("🛑 convertByWebView: 已停止对源 URL 的安全访问。")
        }

        return await withCheckedContinuation { continuation in
            let coordinator = SimpleWebViewCoordinator(
                sourceURL: sourceURL,
                pdfURL: pdfURL,
                continuation: continuation
            )
            coordinator.start()
        }
    }
}

@MainActor
private class SimpleWebViewCoordinator: NSObject, WKNavigationDelegate {

    private let sourceURL: URL
    private let pdfURL: URL
    private var continuation: CheckedContinuation<Bool, Never>?
    private var webView: WKWebView?
    private var window: NSWindow?

    private static var activeCoordinators: [UUID: SimpleWebViewCoordinator] = [:]
    private let taskID = UUID()

    init(sourceURL: URL, pdfURL: URL, continuation: CheckedContinuation<Bool, Never>) {
        self.sourceURL = sourceURL
        self.pdfURL = pdfURL
        self.continuation = continuation
        super.init()
    }

    @MainActor
    func start() {
        SimpleWebViewCoordinator.activeCoordinators[taskID] = self

        do {
            let fileData = try Data(contentsOf: sourceURL)

            let mimeType = UTType(filenameExtension: sourceURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

            let configuration = WKWebViewConfiguration()
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842), configuration: configuration)
            webView.navigationDelegate = self
            self.webView = webView

            let offscreenWindow = NSWindow(
                contentRect: webView.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            offscreenWindow.setFrameOrigin(NSPoint(x: -2000, y: -2000))
            offscreenWindow.contentView = webView
            self.window = offscreenWindow

            webView.load(
                fileData,
                mimeType: mimeType,
                characterEncodingName: "UTF-8",
                baseURL: sourceURL.deletingLastPathComponent()
            )

        } catch {
            print("❌ 在加载到 WebView 之前失败: \(error.localizedDescription)")
            resume(with: false)
        }
        // --- 修改结束 ---
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.convertToPDF(webView: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView 加载失败 (didFail): \(error.localizedDescription)")
        resume(with: false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView 初始加载失败 (didFailProvisionalNavigation): \(error.localizedDescription)")
        resume(with: false)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print("❌ WebView 渲染进程意外终止。")
        resume(with: false)
    }

    private func convertToPDF(webView: WKWebView) {
        print("enter convertToPDF")
        let printInfo = NSPrintInfo.shared

        printInfo.jobDisposition = .save

        let printSettings = printInfo.dictionary()

        printSettings[NSPrintInfo.AttributeKey.jobSavingURL] = self.pdfURL

        let customPrintInfo = NSPrintInfo(dictionary: printSettings as! [NSPrintInfo.AttributeKey : Any])

        customPrintInfo.horizontalPagination = .fit
        customPrintInfo.verticalPagination = .fit
        customPrintInfo.isHorizontallyCentered = true
        customPrintInfo.isVerticallyCentered = true

        let printOperation = webView.printOperation(with: customPrintInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false

        printOperation.run()

        let success = FileManager.default.fileExists(atPath: self.pdfURL.path)
        print(success ? "✅ 打印转换成功: \(self.pdfURL.lastPathComponent)" : "❌ 打印转换失败，文件未在目标路径创建。")

        resume(with: success)
    }

    private func resume(with result: Bool) {
        continuation?.resume(returning: result)
        cleanup()
    }

    private func cleanup() {
        continuation = nil
        webView?.navigationDelegate = nil
        webView = nil

        window?.close()
        window = nil

        SimpleWebViewCoordinator.activeCoordinators.removeValue(forKey: taskID)
    }
}

extension UTType {
    /// Microsoft Word Open XML Document (.docx)
    public static let docx = UTType("org.openxmlformats.wordprocessingml.document")!

    /// Microsoft Word 97 Document (.doc)
    public static let doc = UTType("com.microsoft.word.doc")!

    /// Microsoft PowerPoint Open XML Presentation (.pptx)
    public static let pptx = UTType("org.openxmlformats.presentationml.presentation")!

    /// Microsoft PowerPoint 97 Presentation (.ppt)
    public static let ppt = UTType("com.microsoft.powerpoint.ppt")!

    /// Microsoft Excel Open XML Spreadsheet (.xlsx)
    public static let xlsx = UTType("org.openxmlformats.spreadsheetml.sheet")!

    /// Microsoft Excel 97 Spreadsheet (.xls)
    public static let xls = UTType("com.microsoft.excel.xls")!
}


@MainActor
private func convertBySnapshotting(sourceURL: URL, pdfURL: URL) async -> Bool {
    return await withCheckedContinuation { continuation in
        let coordinator = SnapshotCoordinator(
            sourceURL: sourceURL,
            pdfURL: pdfURL,
            continuation: continuation
        )
        coordinator.start()
    }
}


@MainActor
private class SnapshotCoordinator: NSObject, WKNavigationDelegate {
    private let sourceURL: URL
    private let pdfURL: URL
    private var continuation: CheckedContinuation<Bool, Never>?
    private var webView: WKWebView?

    private static var activeCoordinators: [UUID: SnapshotCoordinator] = [:]
    private let taskID = UUID()

    init(sourceURL: URL, pdfURL: URL, continuation: CheckedContinuation<Bool, Never>) {
        self.sourceURL = sourceURL
        self.pdfURL = pdfURL
        self.continuation = continuation
        super.init()
    }

    func start() {
        SnapshotCoordinator.activeCoordinators[taskID] = self

        do {
            let fileData = try Data(contentsOf: sourceURL)
            let mimeType = UTType(filenameExtension: sourceURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

            let configuration = WKWebViewConfiguration()
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 1600), configuration: configuration)
            webView.navigationDelegate = self
            self.webView = webView

            let offscreenWindow = NSWindow(
                contentRect: webView.frame,
                styleMask: [.borderless], backing: .buffered, defer: false
            )
            offscreenWindow.setFrameOrigin(NSPoint(x: -3000, y: -3000))
            offscreenWindow.contentView = webView

            webView.load(fileData, mimeType: mimeType, characterEncodingName: "UTF-8", baseURL: sourceURL.deletingLastPathComponent())
        } catch {
            resume(with: false)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.takeSnapshotAndSaveAsPDF(webView: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        resume(with: false)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        resume(with: false)
    }

    private func takeSnapshotAndSaveAsPDF(webView: WKWebView) {
        Task {
            do {
                let snapshotImage = try await webView.takeSnapshot(configuration: nil)

                let pdfData = NSMutableData()

                var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)

                guard let consumer = CGDataConsumer(data: pdfData),
                      let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                    resume(with: false)
                    return
                }

                let graphicsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
                NSGraphicsContext.current = graphicsContext

                pdfContext.beginPDFPage(nil)

                let imageRect = CGRect(origin: .zero, size: snapshotImage.size)
                snapshotImage.draw(in: mediaBox, from: imageRect, operation: .sourceOver, fraction: 1.0)

                pdfContext.endPDFPage()
                pdfContext.closePDF()

                try pdfData.write(to: self.pdfURL)

                print("✅ [截图转换] 成功将 \(sourceURL.lastPathComponent) 转换为 PDF: \(pdfURL)。")
                resume(with: true)

            } catch {
                print("❌ [截图转换] takeSnapshot 或保存失败: \(error)")
                resume(with: false)
            }
        }
    }

    private func resume(with result: Bool) {
        continuation?.resume(returning: result)
        cleanup()
    }

    private func cleanup() {
        continuation = nil
        webView?.navigationDelegate = nil
        webView = nil
        SnapshotCoordinator.activeCoordinators.removeValue(forKey: taskID)
    }
}
