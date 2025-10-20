import SwiftUI
import MarkdownUI
import SwiftUIIntrospect
import SwiftUIX

enum CodeFoldState {
    case partial
    case full
}

struct CodeBlockView: View {
    @Environment(ConversationDetailModel.self) private var detailModel
    
    let configuration: CodeBlockConfiguration
    
    @State private var codeFoldState: CodeFoldState = .partial
    
    private let partialLineLimit = 20
        
    private var language: String {
        let lang = configuration.language ?? "code"
        return lang.isEmpty ? "code" : lang
    }
    
    private var needsFoldingControl: Bool {
        totalLineCount > partialLineLimit && !detailModel.inferring
    }
    
    private var currentLineLimit: Int? {
        if needsFoldingControl && codeFoldState == .partial {
            return partialLineLimit
        }
        return nil
    }
    
    private var totalLineCount: Int {
        configuration.content.components(separatedBy: .newlines).count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if needsFoldingControl {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .rotationEffect(.degrees(codeFoldState == .full ? 90 : 0))
                }
                
                Text(language)
                    .font(.system(size: 14, design: .monospaced))
                    .fontWeight(.semibold)
                    .fixedSize()
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(ToolbarIconButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                if needsFoldingControl {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        codeFoldState = (codeFoldState == .full) ? .partial : .full
                    }
                }
            }
            
            Divider()
            
            ScrollView(.horizontal, showsIndicators: true) {
                LazyView {
                    configuration.label
                        .lineLimit(currentLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.225))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.9))
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                }
            }
            //.transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            
            if needsFoldingControl {
                Divider()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            codeFoldState = (codeFoldState == .full) ? .partial : .full
                        }
                    }) {
                        Label(
                            codeFoldState == .full ? "Collapse" : "Expand All (\(totalLineCount) lines)",
                            systemImage: codeFoldState == .full ? "arrow.up.right.and.arrow.down.left" : "arrow.down.right.and.arrow.up.left"
                        )
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .background(MarkdownColours.secondaryBackground)
            }
        }
        .background(MarkdownColours.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .markdownMargin(top: .zero, bottom: .em(0.8))
    }
    
    private func copyToClipboard() {
        Clipboard.shared.setString(configuration.content)
        detailModel.toastMessage = "Block is copied"
        detailModel.showToast.toggle()
    }
}

struct GrowingButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

final class ForwardingHostingView<Content>: NSHostingView<Content> where Content: View {
    override func wantsForwardedScrollEvents(for axis: NSEvent.GestureAxis) -> Bool {
        return axis == .vertical
    }
}

struct ForwardingScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    func makeNSView(context: Context) -> ForwardingHostingView<Content> {
        ForwardingHostingView(rootView: content)
    }

    func updateNSView(_ nsView: ForwardingHostingView<Content>, context: Context) {
        nsView.rootView = content
    }
}

func splitMarkdownByBlocks(_ text: String) -> [String] {
    let maxLength = 500
    var result: [String] = []
    var currentIndex = text.startIndex

    while currentIndex < text.endIndex {
        print("currentIndex: \(currentIndex)")

        let nextIndex = text.index(currentIndex, offsetBy: maxLength, limitedBy: text.endIndex) ?? text.endIndex
        let chunk = text[currentIndex..<nextIndex]
        result.append(String(chunk))
        currentIndex = nextIndex
    }

    return result
}
