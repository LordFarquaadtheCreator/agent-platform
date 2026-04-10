import SwiftUI

/// Reusable button with async action and loading state
public struct AsyncActionButton: View {
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let action: () async throws -> Void
    let onError: ((Error) -> Void)?

    @State private var isLoading = false
    @State private var error: Error?
    @State private var currentTask: Task<Void, Never>?

    public init(
        title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        action: @escaping () async throws -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
        self.onError = onError
    }

    public var body: some View {
        Button(role: role) {
            performAction()
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else if let image = systemImage {
                    Image(systemName: image)
                        .frame(width: 16, height: 16)
                }
                Text(title)
            }
        }
        .disabled(isLoading)
        .onDisappear {
            cancelTask()
        }
    }

    private func performAction() {
        // Cancel any existing task
        cancelTask()

        isLoading = true
        currentTask = Task {
            do {
                try await action()
                await MainActor.run {
                    isLoading = false
                    currentTask = nil
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    self.error = error
                    currentTask = nil
                    onError?(error)
                }
            }
        }
    }

    private func cancelTask() {
        currentTask?.cancel()
        currentTask = nil
    }
}

/// Button style variant for common actions
public struct ApproveButton: View {
    let action: () async throws -> Void

    public init(action: @escaping () async throws -> Void) {
        self.action = action
    }

    public var body: some View {
        AsyncActionButton(
            title: "Approve",
            systemImage: "checkmark.circle",
            action: action
        )
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }
}

public struct RejectButton: View {
    let action: () async throws -> Void

    public init(action: @escaping () async throws -> Void) {
        self.action = action
    }

    public var body: some View {
        AsyncActionButton(
            title: "Reject",
            systemImage: "xmark.circle",
            role: .destructive,
            action: action
        )
        .buttonStyle(.bordered)
    }
}

public struct PublishButton: View {
    let action: () async throws -> Void

    public init(action: @escaping () async throws -> Void) {
        self.action = action
    }

    public var body: some View {
        AsyncActionButton(
            title: "Publish",
            systemImage: "arrow.up.circle",
            action: action
        )
        .buttonStyle(.borderedProminent)
    }
}

#Preview {
    VStack(spacing: 16) {
        AsyncActionButton(title: "Save", systemImage: "checkmark") {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        ApproveButton {
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        RejectButton {
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        PublishButton {
            try await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    .padding()
}
