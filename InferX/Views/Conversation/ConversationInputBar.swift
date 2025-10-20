import SwiftUI
import SwiftUIIntrospect
import Defaults

struct ConversationInputBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ConversationDetailModel.self) private var detailModel
    @Environment(ModelManagerModel.self) private var modelManager

    @Binding var messageText: String
    let onSend: () -> Void
    let attachments: [Attachment]
    let onAttachAdd: () -> Void
    let onAttachRemove: (UUID) -> Void
    let onReAttach: (UUID) -> Void
    let isDragOver: Bool

    @State private var dynamicHeight: CGFloat = 40
    @FocusState private var isFocused: Bool

    @State private var isHoveringOnInput = false
    @State private var isHoveringOnButton = false
    @State private var generatingTextOpacity: Double = 1.0

    let maxHeight: CGFloat = 300
    let minHeight: CGFloat = 30
    let thumbnailViewHeight: CGFloat = 100

    private var multiColorGradientBackgroundForFocus: LinearGradient {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.1),
                Color.blue.opacity(0.1),
                Color.green.opacity(0.1),
                Color.yellow.opacity(0.1),
                Color.red.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var multiColorGradientBorderForFocus: LinearGradient {
        LinearGradient(
            colors: [
                Color.purple,
                Color.blue,
                Color.green,
                Color.yellow,
                Color.red
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var inputBackgroundFill: AnyShapeStyle {
        let conversation = detailModel.conversation
        let model = modelManager.getModel(modelID: conversation?.modelID)
        if isFocused && !detailModel.inferring {
            //return AnyShapeStyle(multiColorGradientBackgroundForFocus)
            return AnyShapeStyle(Color(.controlBackgroundColor).opacity(0.5))
        } else if isHoveringOnInput && (model?.isAvailable ?? false) {
            return AnyShapeStyle(Color(.controlBackgroundColor).opacity(0.5))
        } else {
            return AnyShapeStyle(Color(.controlBackgroundColor).opacity(0.2))
        }
    }

    var body: some View {
        VStack {
            Spacer()

            GeometryReader { geometry in
                HStack(alignment: .center, spacing: 12) {
                    let conversation = detailModel.conversation
                    let model = modelManager.getModel(modelID: conversation?.modelID)
                    let modelMeta = modelManager.getModelMeta(for: model)
                    
                    Button(action: onAttachAdd) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(isHoveringOnButton ? .accentColor : .secondary)
                            .scaleEffect(isHoveringOnButton ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoveringOnButton)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringOnButton = $0 }
                    .frame(height: minHeight)
                    .disabled(!(modelMeta?.mediaSupport ?? false) || detailModel.inferring || !(model?.isAvailable ?? false))

                    VStack(spacing: 5) {
                        if !attachments.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(attachments) { attachment in
                                        AttachmentThumbnailView(
                                            attachment: attachment,
                                            onRemove: onAttachRemove,
                                            onReAttach: onReAttach
                                        )
                                    }
                                }
                                .padding(5)
                            }
                            .frame(height: thumbnailViewHeight)
                            .transition(.opacity.combined(with: .scale))
                        }

                        if detailModel.inferring {
                            HStack {
                                Text("Generating...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .opacity(generatingTextOpacity)
                                    .onAppear {
                                        generatingTextOpacity = 1.0
                                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                            generatingTextOpacity = 0.4
                                        }
                                    }
                                    .onDisappear {
                                        generatingTextOpacity = 1.0
                                    }
                                Spacer()
                            }
                            .padding(.horizontal, 5)
                            .frame(minHeight: minHeight)
                            .hidden(isDragOver)
                        } else {
                            UltramanTextEditor(
                                text: $messageText,
                                placeholder: "Type your message…",
                                onSubmit: {
                                    onSend()
                                    isFocused = false
                                }
                            )
                            .font(.system(size: 14))
                            .foregroundColor(Color(.controlTextColor))
                            .accentColor(Color(.controlAccentColor))
                            .focused($isFocused)
                            .onExitCommand {
                                isFocused = false
                            }
                            .disabled(detailModel.inferring || !(model?.isAvailable ?? false))
                            .frame(
                                width: geometry.size.width - 150,
                                height: max(
                                    minHeight,
                                    attachments.isEmpty ? dynamicHeight - 10 : dynamicHeight - 10 - thumbnailViewHeight
                                )
                            )
                            .padding(2)
                        }
                    }
                    .background({
                        RoundedRectangle(cornerRadius: 20)
                            .fill(inputBackgroundFill)
                            .overlay {
                                if detailModel.inferring || isFocused {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(multiColorGradientBorderForFocus.opacity(Defaults[.appleIntelligenceEffect] ? 1 : 0), lineWidth: 2)
                                        .blur(radius: 4)
                                } else if isHoveringOnInput && (model?.isAvailable ?? false) {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.gray.opacity(0.8), lineWidth: 1)
                                } else {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                                }
                            }
                    })
                    .onHover { isHoveringOnInput = $0 }
                    .padding(10)
                    .hidden(isDragOver)

                    Button {
                        if detailModel.inferring {
                            detailModel.inferStopping = true
                            detailModel.chatTask?.cancel()
                        } else {
                            onSend()
                        }
                    } label: {
                        if detailModel.inferring {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .symbolEffect(.variableColor, isActive: detailModel.inferStopping)
                                .foregroundColor(.primary)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8)
                                .frame(height: 25)
                        } else {
                            Label("Send", systemImage: "paperplane")
                                .opacity(detailModel.inferring ? 0.7 : 1.0)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8)
                                .frame(height: 25)
                        }
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty && !detailModel.inferring)
                    .onChange(of: detailModel.inferring) { _, running in
                        detailModel.inferStopping = !running
                    }
                    .frame(height: minHeight)
                }
                .onChange(of: messageText) {
                    recalculateHeight(for: geometry.size.width - 150)
                }
                .onChange(of: attachments) {
                    recalculateHeight(for: geometry.size.width - 150)
                }
            }
        }
        .frame(height: dynamicHeight)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.3), value: dynamicHeight)
        .animation(.spring(), value: attachments.isEmpty)
    }

    private func recalculateHeight(for width: CGFloat) {
        let textView = NSTextView()
        textView.string = messageText
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedSize = textView.layoutManager?.usedRect(for: textView.textContainer!).size ?? .zero
        
        let attachmentsHeight = attachments.isEmpty ? 0 : thumbnailViewHeight
        let textHeight = usedSize.height + 20

        dynamicHeight = min(max(textHeight + attachmentsHeight, minHeight), maxHeight + attachmentsHeight)
    }
    
    private struct InferringEffectView: View {
        private let gradientColors: [Color] = [
            .purple, .blue, .cyan, .green, .yellow, .pink, .purple
        ]

        var body: some View {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSince1970
                
                let borderAngle = Angle.degrees(fmod(time * 20, 360))
                
                let backgroundSinTime = sin(time * 0.4)
                let backgroundCosTime = cos(time * 0.4)
                let backgroundStartPoint = UnitPoint(x: (backgroundSinTime + 1) / 2, y: (backgroundCosTime + 1) / 2)
                let backgroundEndPoint = UnitPoint(x: 1 - backgroundStartPoint.x, y: 1 - backgroundStartPoint.y)

                let backgroundGradient = LinearGradient(
                    gradient: Gradient(colors: gradientColors.map { $0.opacity(0.2) }),
                    startPoint: backgroundStartPoint,
                    endPoint: backgroundEndPoint
                )

                let borderGradient = AngularGradient(
                    gradient: Gradient(colors: gradientColors),
                    center: .center,
                    angle: borderAngle
                )
                
                let shape = RoundedRectangle(cornerRadius: 20)

                shape
                    .fill(backgroundGradient)
                    .overlay(
                        shape
                            .stroke(borderGradient, lineWidth: 3)
                            .blur(radius: 4)
                    )
            }
        }
    }
}
