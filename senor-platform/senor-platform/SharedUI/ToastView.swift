import SwiftUI

// MARK: - Toast Notification System

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastMessage?
    
    func show(message: String, duration: TimeInterval = 3.0) {
        currentToast = ToastMessage(message: message, duration: duration)
    }
}

struct ToastMessage: Identifiable {
    let id = UUID()
    let message: String
    let duration: TimeInterval
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        AppSurface(style: .elevated) {
            AppHStack(spacing: .medium) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.ColorToken.statusWarning)
                AppText(message, style: .body)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 400)
    }
}

struct ToastOverlay: ViewModifier {
    @StateObject private var toastManager = ToastManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    ToastView(message: toast.message)
                        .padding(.top, AppTheme.Spacing.large)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                                withAnimation {
                                    toastManager.currentToast = nil
                                }
                            }
                        }
                }
            }
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
