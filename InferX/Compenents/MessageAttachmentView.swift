//
//  MessageAttachmentView.swift
//  InferX
//
//  Created by mingdw on 2025/4/6.
//

import SwiftUI
import AVKit

#if os(macOS)
import AppKit

struct MessageAttachmentView: View {
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    var attachmentData: AttachmentData

    @State private var showingAlert = false
    @State private var alertMessage: LocalizedStringKey = ""
    @State private var showingImageViewer = false
    @State private var showingVideoPlayer = false
    @State private var fileURL: URL?
    @State private var imageData: Data?
    @State private var isHovered = false

    private var resolvedURL: URL? {
        var bookmark = attachmentData.bookmark
        return FileManager.default.getResolvedURL(from: &bookmark)
    }

    private var fileName: String {
        resolvedURL?.lastPathComponent ?? "Attachment"
    }

    private var fileExtension: String {
        resolvedURL?.pathExtension.lowercased() ?? ""
    }

    private var isImageFile: Bool {
        ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"].contains(fileExtension)
    }

    private var isVideoFile: Bool {
        ["mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv"].contains(fileExtension)
    }

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
            .help(isVideoFile ? "Tap to play video" : (isImageFile ? "Tap to view image" : "Tap to open file"))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .contextMenu {
                Button {
                    copyFilePath()
                } label: {
                    Text("Copy File Path")
                }
            }

            Text(truncatedFileName(fileName))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(width: 80)
                .padding(.top, 2)
        }
        .onAppear {
            fileURL = resolvedURL
            imageData = attachmentData.thumbnail
        }
        .sheet(isPresented: $showingImageViewer) {
            if let data = imageData {
                MacImageViewer(imageData: data, fileName: fileName)
                    .environment(\.locale, locale)
                    .environment(\.layoutDirection, layoutDirection)
            }
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let fileURL {
                MacVideoPlayer(videoURL: fileURL)
                    .environment(\.locale, locale)
                    .environment(\.layoutDirection, layoutDirection)
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func handleThumbnailTap() {
        guard let url = resolvedURL else { return }

        if isImageFile {
            guard let securedURL = FileManager.default.securityAccessFile(url: url) else {
                alertMessage = "Unable to start security-scoped access to the URL."
                showingAlert = true
                return
            }

            defer { securedURL.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: securedURL) {
                imageData = data
                showingImageViewer = true
            } else {
                alertMessage = "Failed to read image file."
                showingAlert = true
            }
        } else if isVideoFile {
            showingVideoPlayer = true
        } else {
            openFile(url)
        }
    }

    private func openFile(_ url: URL) {
        guard let fileUrl = FileManager.default.securityAccessFile(url: url) else {
            alertMessage = "Unable to start security-scoped access to the URL."
            showingAlert = true
            return
        }

        defer { fileUrl.stopAccessingSecurityScopedResource() }
        NSWorkspace.shared.open(fileUrl)
    }

    private func copyFilePath() {
        guard let fileURL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fileURL.path, forType: .string)
    }

    private func truncatedFileName(_ fileName: String, maxLength: Int = 15) -> String {
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
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(.black.opacity(0.5))
            .opacity(isZoomed ? 0 : 1)
            .zIndex(1)

#if os(macOS)
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
                Text("Unable to load image")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
#else
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
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
                Text("Unable to load image")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
#endif
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
                Button("Done") {
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
                Text("Loading video...")
                    .frame(minWidth: 600, minHeight: 400)
                    .onAppear {
                        guard let securedURL = FileManager.default.securityAccessFile(url: videoURL) else {
                            print("❌ 无法开始对 URL 的安全访问。")
                            return
                        }
                        self.player = AVPlayer(url: securedURL)
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

#else
import UIKit

struct MessageAttachmentView: View {
    var attachmentData: AttachmentData

    var body: some View {
        VStack(spacing: 4) {
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

            Text(resolvedFileName)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(width: 80)
                .padding(.top, 2)
        }
    }

    private var resolvedFileName: String {
        var bookmark = attachmentData.bookmark
        let url = FileManager.default.getResolvedURL(from: &bookmark)
        return url?.lastPathComponent ?? "Attachment"
    }
}

#endif
