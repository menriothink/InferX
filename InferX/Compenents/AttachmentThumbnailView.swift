//
//  AttachmentThumbnailView.swift
//  InferX
//
//  Created by mingdw on 2025/9/10.
//

import SwiftUI
import Foundation

struct AttachmentThumbnailView: View {
    let attachment: Attachment
    let onRemove: (UUID) -> Void
    let onReAttach: (UUID) -> Void

    private let maxBlurRadius: CGFloat = 1

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                let thumbnail = attachment.thumbnail ?? Image(systemName: "doc")
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .blur(radius: maxBlurRadius * (1.0 - attachment.progress.fractionCompleted))
                    .animation(.easeInOut(duration: 0.5), value: attachment.progress.fractionCompleted)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(alignment: .bottom) {
                        if attachment.status != .done {
                            ProgressView(value: attachment.progress.fractionCompleted)
                                .progressViewStyle(.linear)
                                .tint(attachment.status == .uploading ? .accentColor : .red)
                                    .background(.clear)
                                    .clipShape(Capsule())
                                    .transition(.opacity.animation(.easeInOut))
                                    .offset(y: 6)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if attachment.status == .pause {
                            Button(action: { onReAttach(attachment.id) }) {
                                Image(systemName: "play.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 5, y: 5)
                        }
                    }

                Button(action: { onRemove(attachment.id) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: 5)
            }
            .frame(width: 60, height: 60)

            Text(attachment.location.lastPathComponent)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
        .padding(5)
    }
}
