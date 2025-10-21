//
//  Theme+EN.swift
//  InferX
//
//  Created by mingdw on 2025/4/17.
//

import SwiftUI
import MarkdownUI

struct MarkdownColours {
    static let text = Color(
        light: Color(rgba: 0x0606_06ff), dark: Color(rgba: 0xfbfb_fcff)
    )
    static let secondaryText = Color(
        light: Color(rgba: 0x6b6e_7bff), dark: Color(rgba: 0x9294_a0ff)
    )
    static let tertiaryText = Color(
        light: Color(rgba: 0x6b6e_7bff), dark: Color(rgba: 0x6d70_7dff)
    )
    static let background = Color(
        light: .white, dark: Color(rgba: 0x1819_1dff)
    )
    static let secondaryBackground = Color(
        //light: Color(rgba: 0xf7f7_f9ff), dark: Color(rgba: 0x2526_2aff)
        light: Color(.gray.opacity(0.05)), dark: Color(rgba: 0x2526_2aff)
    )
    static let link = Color(
        light: Color(rgba: 0x2c65_cfff), dark: Color(rgba: 0x4c8e_f8ff)
    )
    static let border = Color(
        light: Color(rgba: 0xe4e4_e8ff), dark: Color(rgba: 0x4244_4eff)
    )
    static let divider = Color(
        light: Color(rgba: 0xd0d0_d3ff), dark: Color(rgba: 0x3334_38ff)
    )
    static let checkbox = Color(rgba: 0xb9b9_bbff)
    static let checkboxBackground = Color(rgba: 0xeeee_efff)
    
    @MainActor static let enchantedThemeSmall = enchantedTheme(fontSize: 12)
    @MainActor static let enchantedThemeMedium = enchantedTheme(fontSize: 13)
    @MainActor static let enchantedThemeLarge = enchantedTheme(fontSize: 14)
    
    @MainActor
    static func enchantedTheme(fontName: String = "System Font",
                               fontSize: CGFloat = 14,
                               fontWeight: FontWeightOption = .regular) -> Theme {
        return Theme()
            .text {
                ForegroundColor(.primary)
            }
            .code {
                FontFamily(.custom("SF Mono"))
                FontSize(.em(0.85))
                FontFamilyVariant(.monospaced)
                FontWeight(.regular)
                ForegroundColor(Color.primary.opacity(0.85))
            }
            .link {
                ForegroundColor(link)
            }
            .heading1 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    CustomThemView(
                        configuration: configuration,
                        setFontWeight: .black,
                        scale: 2
                    )
                    Divider().overlay(divider)
                }
            }
            .heading2 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    CustomThemView(
                        configuration: configuration,
                        setFontWeight: .semibold,
                        scale: 1.8
                    )
                    Divider().overlay(divider)
                }
            }
            .heading3 { configuration in
                CustomThemView(
                    configuration: configuration,
                    setFontWeight: .semibold,
                    scale: 1.6
                )
            }
            .heading4 { configuration in
                CustomThemView(
                    configuration: configuration,
                    setFontWeight: .semibold,
                    scale: 1.4
                )
                //.background(RoundedRectangle(cornerRadius: 4).stroke(Color.blue, lineWidth: 1)) // Debug
                //.padding(.vertical, 10)
            }
            .heading5 { configuration in
                CustomThemView(
                    configuration: configuration,
                    setFontWeight: .semibold,
                    scale: 1.2
                )
            }
            .heading6 { configuration in
                CustomThemView(
                    configuration: configuration,
                    setFontWeight: .semibold
                )
            }
            .paragraph { configuration in
                CustomThemView(
                    configuration: configuration,
                    scale: 0.95
                )
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(border)
                        .relativeFrame(width: .em(0.2))
                    
                    CustomThemView(configuration: configuration)
                        .markdownTextStyle { ForegroundColor(secondaryText) }
                        .relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .codeBlock { configuration in
                CodeBlockView(configuration: configuration)
                    .markdownTextStyle {
                        FontFamily(.custom("SF Mono"))
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.95))
                        FontWeight(.regular)
                    }
                    .padding(.vertical, 5)
                    .frame(alignment: .leading)
            }
            .listItem { configuration in
                CustomThemView(configuration: configuration)
            }
            .taskListMarker { configuration in
                Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(checkbox, checkboxBackground)
                    .imageScale(.small)
                    .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
            }
            .table { configuration in
                CustomThemView(configuration: configuration)
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: border))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(background, secondaryBackground)
                    )
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                        }
                        BackgroundColor(nil)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 13)
                    .relativeLineSpacing(.em(0.25))
            }
            .thematicBreak {
                Divider()
                    .relativeFrame(height: .em(0.25))
                    .overlay(border)
                    .markdownMargin(top: 24, bottom: 24)
            }
            .image { configuration in
                configuration.label
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
    }
}
