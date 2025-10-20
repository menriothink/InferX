import SwiftUI
import MarkdownUI
import Defaults

struct CustomThemView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.processedContent) private var processedContent
    
    @Default(.fontWeightBlack) var fontWeightBlack
    @Default(.fontWeightWhite) var fontWeightWhite
    @Default(.fontSizeBlack) var fontSizeBlack
    @Default(.fontSizeWhite) var fontSizeWhite
    @Default(.fontNameWhite) var fontNameWhite
    @Default(.fontNameBlack) var fontNameBlack
    
    var fontName: String {
        get {
            colorScheme == .dark ? fontNameBlack : fontNameWhite
        }
    }
    
    var fontWeight: FontWeightOption {
        get {
            colorScheme == .dark ? fontWeightBlack : fontWeightWhite
        }
    }
    
    var fontSize: CGFloat {
        colorScheme == .dark ? fontSizeBlack : fontSizeWhite
    }
    
    let configuration: BlockConfiguration
    var setFontWeight: FontWeightOption? = nil
    var scale: CGFloat = 1
    
    var body: some View {
        let plainText = configuration.content.renderPlainText()
        if let cachedContent = matchBlockPlaceholder(plainString: plainText, contentCache: processedContent.contentCache)
        {
            renderBlock(fontSize: fontSize, fontWeight: fontWeight, cachedContent: cachedContent)
        } else {
            configuration.label
                .relativeLineSpacing(.em(0.5*scale))
                .markdownMargin(top: 10, bottom: 20*scale)
                .markdownTextStyle {
                    FontWeight(setFontWeight?.actualWeight ?? fontWeight.actualWeight)
                    FontSize(.em(scale))
                    ForegroundColor(colorScheme == .dark ? .white : .black)
                }
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
