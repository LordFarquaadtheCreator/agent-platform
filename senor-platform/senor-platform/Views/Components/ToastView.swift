import SwiftUI

struct ToastView: View {
    let message: String
    let systemImage: String?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(AppTheme.Typography.caption)
            }
            AppText(message, style: .caption)
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(AppTheme.ColorToken.chromeBackground.opacity(0.95))
        .foregroundStyle(AppTheme.ColorToken.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        .shadow(
            color: AppTheme.Shadow.toast.color,
            radius: AppTheme.Shadow.toast.radius,
            x: AppTheme.Shadow.toast.x,
            y: AppTheme.Shadow.toast.y
        )
    }
}

struct ToastOverlayModifier: ViewModifier {
    @Binding var message: String?
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isVisible, let message = message {
                    ToastView(message: message, systemImage: "checkmark.circle.fill")
                        .padding(.top, AppTheme.Spacing.medium)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: message) { _, newValue in
                if newValue != nil {
                    withAnimation(.spring(duration: 0.3)) {
                        isVisible = true
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await MainActor.run {
                            withAnimation(.spring(duration: 0.3)) {
                                isVisible = false
                            }
                            self.message = nil
                        }
                    }
                }
            }
    }
}

extension View {
    func toast(message: Binding<String?>) -> some View {
        modifier(ToastOverlayModifier(message: message))
    }
}
