import SwiftUI
import MarkdownUI

// MARK: - App Markdown Theme
// Extends MarkdownUI Theme with app design tokens.
// Use `.markdownTheme(.app)` for markdown content that should conform to app styling.

public extension Theme {
    static var app: Theme {
        Theme()
            .text {
                FontFamily(.system())
                ForegroundColor(AppTheme.ColorToken.textPrimary)
            }
            .paragraph { configuration in
                configuration.label
                    .markdownMargin(top: .zero, bottom: .em(0.5))
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamily(.system())
                        FontWeight(.semibold)
                        ForegroundColor(AppTheme.ColorToken.textPrimary)
                    }
                    .markdownMargin(top: .em(0.8), bottom: .em(0.4))
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamily(.system())
                        FontWeight(.semibold)
                        ForegroundColor(AppTheme.ColorToken.textPrimary)
                    }
                    .markdownMargin(top: .em(0.6), bottom: .em(0.3))
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamily(.system())
                        FontWeight(.semibold)
                        ForegroundColor(AppTheme.ColorToken.textPrimary)
                    }
                    .markdownMargin(top: .em(0.5), bottom: .em(0.2))
            }
            .code {
                FontFamily(.custom("SF Mono"))
                BackgroundColor(AppTheme.ColorToken.sectionBackground)
            }
            .codeBlock { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamily(.custom("SF Mono"))
                        FontSize(.em(0.85))
                    }
                    .padding(AppTheme.Spacing.small)
                    .background(AppTheme.ColorToken.sectionBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
                    .markdownMargin(top: .zero, bottom: .em(0.5))
            }
            .blockquote { configuration in
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(AppTheme.ColorToken.textSecondary)
                    }
                    .padding(.leading, AppTheme.Spacing.small)
                    .overlay(
                        Rectangle()
                            .fill(AppTheme.ColorToken.textSecondary)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity),
                        alignment: .leading
                    )
                    .markdownMargin(top: .zero, bottom: .em(0.5))
            }
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: .zero, bottom: .em(0.2))
            }
            .thematicBreak {
                Divider()
                    .markdownMargin(top: .em(0.5), bottom: .em(0.5))
            }
            .link {
                ForegroundColor(AppTheme.ColorToken.accent)
            }
    }
}
