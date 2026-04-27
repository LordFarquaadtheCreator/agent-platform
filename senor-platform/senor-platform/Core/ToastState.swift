import SwiftUI
import Combine

@MainActor
final class ToastState: ObservableObject {
    static let shared = ToastState()
    @Published var message: String?
}
