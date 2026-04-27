import SwiftUI

// MARK: - AppText
// Text with tokenized font and color. Replaces raw .font(...) and .foregroundStyle(...).

enum AppTextStyle {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case callout
    case caption
    case caption2
    case metricValue
    case metricLabel
    case monospace
    case monospaceCaption
}

struct AppText: View {
    let text: String
    let style: AppTextStyle
    let color: Color?

    init(_ text: String, style: AppTextStyle, color: Color? = nil) {
        self.text = text
        self.style = style
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(fontForStyle(style))
            .foregroundStyle(color ?? defaultColorForStyle(style))
    }

    private func fontForStyle(_ style: AppTextStyle) -> Font {
        switch style {
        case .largeTitle: return AppTheme.Typography.largeTitle
        case .title: return AppTheme.Typography.title
        case .title2: return AppTheme.Typography.title2
        case .title3: return AppTheme.Typography.title3
        case .headline: return AppTheme.Typography.headline
        case .subheadline: return AppTheme.Typography.subheadline
        case .body: return AppTheme.Typography.body
        case .callout: return AppTheme.Typography.callout
        case .caption: return AppTheme.Typography.caption
        case .caption2: return AppTheme.Typography.caption2
        case .metricValue: return AppTheme.Typography.metricValue
        case .metricLabel: return AppTheme.Typography.metricLabel
        case .monospace: return AppTheme.Typography.monospace
        case .monospaceCaption: return AppTheme.Typography.monospaceCaption
        }
    }

    private func defaultColorForStyle(_ style: AppTextStyle) -> Color {
        switch style {
        case .metricLabel, .caption, .caption2, .subheadline:
            return AppTheme.ColorToken.textSecondary

        default:
            return AppTheme.ColorToken.textPrimary
        }
    }
}

// MARK: - AppSurface
// Generic elevated or flat container. Replaces raw .background/.cornerRadius/.shadow.

enum AppSurfaceStyle {
    case card
    case flat
    case elevated
}

struct AppSurface<Content: View>: View {
    let style: AppSurfaceStyle
    let content: Content

    init(style: AppSurfaceStyle, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppTheme.Spacing.cardPadding)
            .background(backgroundForStyle(style))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
            .overlay(overlayForStyle(style))
            .shadow(
                color: shadowForStyle(style).color,
                radius: shadowForStyle(style).radius,
                x: shadowForStyle(style).x,
                y: shadowForStyle(style).y
            )
    }

    private func backgroundForStyle(_ style: AppSurfaceStyle) -> Color {
        AppTheme.ColorToken.cardBackground
    }

    private func overlayForStyle(_ style: AppSurfaceStyle) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
            .stroke(AppTheme.ColorToken.subtleBorder, lineWidth: 1)
    }

    private func shadowForStyle(_ style: AppSurfaceStyle) -> AppTheme.ShadowStyle {
        switch style {
        case .card: return AppTheme.Shadow.subtle
        case .flat: return AppTheme.Shadow.clear
        case .elevated: return AppTheme.Shadow.elevated
        }
    }
}

// MARK: - AppStack
// V/H/ZStack with semantic spacing. Replaces raw VStack(spacing: 4).

enum AppStackSpacing {
    case tight
    case small
    case medium
    case large
}

struct AppVStack<Content: View>: View {
    let spacing: AppStackSpacing
    let alignment: HorizontalAlignment
    let content: Content

    init(
        spacing: AppStackSpacing = .medium,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        VStack(alignment: alignment, spacing: valueForSpacing(spacing)) {
            content
        }
    }

    private func valueForSpacing(_ spacing: AppStackSpacing) -> CGFloat {
        switch spacing {
        case .tight: return AppTheme.Spacing.tightGap
        case .small: return AppTheme.Spacing.small
        case .medium: return AppTheme.Spacing.medium
        case .large: return AppTheme.Spacing.large
        }
    }
}

struct AppHStack<Content: View>: View {
    let spacing: AppStackSpacing
    let alignment: VerticalAlignment
    let content: Content

    init(
        spacing: AppStackSpacing = .medium,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: valueForSpacing(spacing)) {
            content
        }
    }

    private func valueForSpacing(_ spacing: AppStackSpacing) -> CGFloat {
        switch spacing {
        case .tight: return AppTheme.Spacing.tightGap
        case .small: return AppTheme.Spacing.small
        case .medium: return AppTheme.Spacing.medium
        case .large: return AppTheme.Spacing.large
        }
    }
}

// MARK: - AppListRow
// Row wrapper with tokenized padding. Replaces raw .padding(.vertical, 4).

struct AppListRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, AppTheme.Spacing.listRowPadding)
    }
}

// MARK: - AppCard (legacy alias)
// Kept for backward compatibility. Use AppSurface instead for new code.

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        AppSurface(style: .card) {
            content
        }
    }
}

// MARK: - AppMetricCard
// Fixed to use tokens instead of hardcoded fonts.

struct AppMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        AppSurface(style: .card) {
            AppVStack(spacing: .small) {
                Image(systemName: icon)
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(tint)
                AppText(value, style: .metricValue)
                AppText(title, style: .metricLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - AppEmptyState
// No changes needed.

struct AppEmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

// MARK: - AppSectionHeader
// Fixed to use tokens instead of hardcoded fonts.

struct AppSectionHeader: View {
    let title: String
    let detail: String?
    let action: AnyView?

    init(title: String, detail: String? = nil, action: AnyView? = nil) {
        self.title = title
        self.detail = detail
        self.action = action
    }

    var body: some View {
        AppHStack(spacing: .small, alignment: .center) {
            AppVStack(spacing: .tight, alignment: .leading) {
                AppText(title, style: .title3)
                if let detail {
                    AppText(detail, style: .caption, color: AppTheme.ColorToken.textSecondary)
                }
            }
            Spacer()
            action
        }
    }
}

// MARK: - AppStatusPill
// Fixed to use tokens.

struct AppStatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        AppText(title, style: .caption, color: color)
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, AppTheme.Spacing.xSmall)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

// MARK: - AppButtonStyle
// Enum for standardized button styles. Use with .buttonStyle().

enum AppButtonStyle {
    case bordered
    case borderedProminent
    case borderedDestructive
    case plain
    case cancel
}

extension View {
    func appButtonStyle(_ style: AppButtonStyle) -> some View {
        switch style {
        case .bordered:
            return AnyView(self.buttonStyle(.bordered))

        case .borderedProminent:
            return AnyView(self.buttonStyle(.borderedProminent))

        case .borderedDestructive:
            return AnyView(self.buttonStyle(.bordered).tint(AppTheme.ColorToken.statusError))

        case .plain:
            return AnyView(self.buttonStyle(.plain))

        case .cancel:
            return AnyView(self.buttonStyle(.bordered).keyboardShortcut(.cancelAction))
        }
    }
}

// MARK: - AppFormSection
// Wrapper for Form sections with tokenized header.

struct AppFormSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            AppText(title, style: .headline)
        }
    }
}

// MARK: - AppDivider
// Standardized divider.

struct AppDivider: View {
    var body: some View {
        Divider()
            .background(AppTheme.ColorToken.divider)
    }
}

// MARK: - AppScreenPadding
// View modifier for consistent screen padding.

struct AppScreenPadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.Spacing.screenPadding)
    }
}

extension View {
    func appScreenPadding() -> some View {
        modifier(AppScreenPadding())
    }
}

// MARK: - AppIcon
// Image with standardized sizing for SF Symbols.

struct AppIcon: View {
    let name: String
    let size: AppIconSize
    let color: Color?

    enum AppIconSize {
        case small
        case medium
        case large

        var font: Font {
            switch self {
            case .small: return AppTheme.Typography.callout.weight(.medium)
            case .medium: return AppTheme.Typography.body.weight(.medium)
            case .large: return AppTheme.Typography.title3.weight(.semibold)
            }
        }
    }

    init(_ name: String, size: AppIconSize = .medium, color: Color? = nil) {
        self.name = name
        self.size = size
        self.color = color
    }

    var body: some View {
        Image(systemName: name)
            .font(size.font)
            .foregroundStyle(color ?? AppTheme.ColorToken.textPrimary)
    }
}

// MARK: - Status Color Mapping
// Centralized status color resolution.

enum AppStatusColor {
    case success
    case warning
    case error
    case info
    case neutral

    var swiftUIColor: Color {
        switch self {
        case .success: return AppTheme.ColorToken.statusSuccess
        case .warning: return AppTheme.ColorToken.statusWarning
        case .error: return AppTheme.ColorToken.statusError
        case .info: return AppTheme.ColorToken.statusInfo
        case .neutral: return AppTheme.ColorToken.statusNeutral
        }
    }
}
