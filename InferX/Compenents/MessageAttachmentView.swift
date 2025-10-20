//
//  MessageAttachmentView.swift
//  InferX
//
//  Created by mingdw on 2025/4/6.
//

import AlertToast
import SwiftUI
import AVKit
import AppKit

struct MessageAttachmentView: View {
    var attachmentData: AttachmentData
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingImageViewer = false
    @State private var showingVideoPlayer = false
    @State private var fileURL: URL?
    @State private var imageData: Data?
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            Button(action: handleThumbnailTap) {
                let thumbnail = Image(data: attachmentData.thumbnail) ?? Image(systemName: "doc")
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if isVideoFile {
                                Image(systemName: "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                    .shadow(color: isHovered ? .black.opacity(0.3) : .clear, radius: 8)
            }
            .buttonStyle(.plain)
            .help(isVideoFile ? "点击播放视频" : (isImageFile ? "点击查看大图" : "点击打开文件"))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .contextMenu {
                /*Button("在 Finder 中显示") {
                    showInFinder()
                }

                if isImageFile {
                    Button("用预览打开") {
                        openWithPreview()
                    }
                }

                if isVideoFile {
                    Button("用 QuickTime 播放") {
                        openWithQuickTime()
                    }
                }*/

                Button("拷贝文件路径") {
                    copyFilePath()
                }

                Divider()

                Button("获取信息") {
                    showFileInfo()
                }
            }

            if let fileName = getFileName() {
                Text(fileName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .alert("文件操作", isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingImageViewer) {
            if let data = imageData, let fileName = getFileName() {
                MacImageViewer(imageData: data, fileName: fileName)
            }
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let url = fileURL {
                MacVideoPlayer(videoURL: url)
            }
        }
    }

    private func handleThumbnailTap() {
        let success = FileManager.default.accessFile(from: attachmentData.bookmark) { url -> Bool in
            guard FileManager.default.fileExists(atPath: url.path) else {
                return false
            }

            self.fileURL = url

            if isImageFile {
                do {
                    let data = try Data(contentsOf: url)
                    DispatchQueue.main.async {
                        self.imageData = data
                        self.showingImageViewer = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.alertMessage = "无法读取图片文件: \(error.localizedDescription)"
                        self.showingAlert = true
                    }
                    return false
                }
            } else if isVideoFile {
                DispatchQueue.main.async {
                    self.showingVideoPlayer = true
                }
            } else {
                NSWorkspace.shared.open(url)
            }

            return true
        }

        if success == nil {
            alertMessage = "无法访问文件，可能已被移动或删除"
            showingAlert = true
        } else if success == false {
            alertMessage = "文件不存在或无法读取"
            showingAlert = true
        }
    }

    private func getFileName() -> String? {
        var bookmark = attachmentData.bookmark
        return FileManager.default.getResolvedURL(from: &bookmark)?.lastPathComponent
    }

    private func showInFinder() {
        FileManager.default.accessFile(from: attachmentData.bookmark) { url -> Void in
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }

    private func openWithPreview() {
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: attachmentData.bookmark,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)

            guard let url = FileManager.default.securityAccessFile(url: url) else {
                print("❌ 无法开始对 URL 的安全访问。")
                return
            }

            let openConfiguration = NSWorkspace.OpenConfiguration()
            openConfiguration.promptsUserIfNeeded = true

            NSWorkspace.shared.open(
                [url],
                withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"),
                configuration: openConfiguration
            ) { runningApplication, error in

                url.stopAccessingSecurityScopedResource()

                if let error = error {
                    print("🚨 打开 '预览.app' 失败: \(error.localizedDescription)")
                } else {
                    print("✅ 成功请求 '预览.app' 打开文件。")
                }
            }

        } catch {
            print("🚨 解析书签失败: \(error.localizedDescription)")
        }
    }

    private func openWithQuickTime() {
        FileManager.default.accessFile(from: attachmentData.bookmark) { url -> Void in
            NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/QuickTime Player.app"), configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
    }

    private func copyFilePath() {
        FileManager.default.accessFile(from: attachmentData.bookmark) { url -> Void in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(url.path, forType: .string)
        }
    }

    private func showFileInfo() {
        FileManager.default.accessFile(from: attachmentData.bookmark) { url -> Void in
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private var isImageFile: Bool {
        guard let filePath = getFilePath() else { return false }
        let fileExtension = URL(fileURLWithPath: filePath).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"].contains(fileExtension)
    }

    private var isVideoFile: Bool {
        guard let filePath = getFilePath() else { return false }
        let fileExtension = URL(fileURLWithPath: filePath).pathExtension.lowercased()
        return ["mp4", "mov", "avi", "mkv", "wmv", "flv", "m4v"].contains(fileExtension)
    }

    private func getFilePath() -> String? {
        var bookmark = attachmentData.bookmark
        return FileManager.default.getResolvedURL(from: &bookmark)?.path
    }

    private func truncateFileName(_ fileName: String) -> String {
        let maxLength = 12

        if fileName.count <= maxLength {
            return fileName
        }

        let url = URL(fileURLWithPath: fileName)
        let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        let truncatedNameLength = maxLength - fileExtension.count - 4
        if truncatedNameLength > 0 {
            let truncatedName = String(nameWithoutExtension.prefix(truncatedNameLength))
            return "\(truncatedName)...\(fileExtension.isEmpty ? "" : ".\(fileExtension)")"
        }

        return fileExtension.isEmpty ? "..." : "...\(fileExtension)"
    }
}

struct MacImageViewer: View {
    let imageData: Data
    let fileName: String
    @Environment(\.dismiss) private var dismiss

    @State private var isZoomed = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(fileName)
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(.black.opacity(0.5))
            .opacity(isZoomed ? 0 : 1)
            .zIndex(1)

            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: isZoomed ? .fill : .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: isZoomed ? .all : [])
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isZoomed.toggle()
                        }
                    }
            } else {
                Text("无法加载图片")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 500, idealWidth: 800, maxWidth: .infinity,
               minHeight: 400, idealHeight: 600, maxHeight: .infinity)
        .background(.black)
    }
}

struct MacVideoPlayer: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        VStack {
            HStack {
                Text(videoURL.lastPathComponent)
                    .font(.headline)
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            if let player = player {
                VideoPlayer(player: player)
                    .frame(minWidth: 600, minHeight: 400)
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Text("正在加载视频...")
                    .frame(minWidth: 600, minHeight: 400)
                    .onAppear {
                        guard let videoURL = FileManager.default.securityAccessFile(url: videoURL) else {
                            print("❌ 无法开始对 URL 的安全访问。")
                            return
                        }
                        self.player = AVPlayer(url: videoURL)
                    }
            }
        }
        .background(Color.black)
        .onDisappear {
            self.player = nil
            videoURL.stopAccessingSecurityScopedResource()
        }
    }
}
