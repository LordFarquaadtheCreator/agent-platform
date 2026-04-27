import SwiftUI

struct ToastView: View {
    let message: String
    let systemImage: String?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.caption)
            }
            AppText(message, style: .caption)
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(AppTheme.ColorToken.textPrimary.opacity(0.9))
        .foregroundStyle(AppTheme.ColorToken.chromeBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
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
