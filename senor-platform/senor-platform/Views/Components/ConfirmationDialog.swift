import SwiftUI

/// Standardized confirmation dialog component
public struct ConfirmationDialog: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    let confirmRole: ButtonRole?
    let onConfirm: () -> Void

    public init(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        confirmRole: ButtonRole? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.confirmRole = confirmRole
        self.onConfirm = onConfirm
    }

    public func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button("Cancel", role: .cancel) {}
                Button(confirmTitle, role: confirmRole) {
                    onConfirm()
                }
            } message: {
                AppText(message, style: .body)
            }
    }
}

public extension View {
    func confirmationDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        confirmRole: ButtonRole? = nil,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmationDialog(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            confirmRole: confirmRole,
            onConfirm: onConfirm
        ))
    }

    func destructiveConfirmation(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "Delete",
        onConfirm: @escaping () -> Void
    ) -> some View {
        confirmationDialog(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            confirmRole: .destructive,
            onConfirm: onConfirm
        )
    }
}

/// Pre-configured dialogs for common actions
public struct DeleteConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let itemName: String
    let onDelete: () -> Void

    public init(isPresented: Binding<Bool>, itemName: String, onDelete: @escaping () -> Void) {
        self._isPresented = isPresented
        self.itemName = itemName
        self.onDelete = onDelete
    }

    public func body(content: Content) -> some View {
        content
            .destructiveConfirmation(
                isPresented: $isPresented,
                title: "Delete \(itemName)?",
                message: "This action cannot be undone.",
                confirmTitle: "Delete",
                onConfirm: onDelete
            )
    }
}

public struct ResetConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let itemName: String
    let onReset: () -> Void

    public init(isPresented: Binding<Bool>, itemName: String, onReset: @escaping () -> Void) {
        self._isPresented = isPresented
        self.itemName = itemName
        self.onReset = onReset
    }

    public func body(content: Content) -> some View {
        content
            .confirmationDialog(
                isPresented: $isPresented,
                title: "Reset \(itemName)?",
                message: "This will revert all changes.",
                confirmTitle: "Reset",
                onConfirm: onReset
            )
    }
}

public extension View {
    func deleteConfirmation(
        isPresented: Binding<Bool>,
        itemName: String,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(DeleteConfirmation(isPresented: isPresented, itemName: itemName, onDelete: onDelete))
    }

    func resetConfirmation(
        isPresented: Binding<Bool>,
        itemName: String,
        onReset: @escaping () -> Void
    ) -> some View {
        modifier(ResetConfirmation(isPresented: isPresented, itemName: itemName, onReset: onReset))
    }
}

#Preview {
    @Previewable @State var showDelete = false
    @Previewable @State var showReset = false

    AppVStack(spacing: .large) {
        Button("Show Delete Dialog") { showDelete = true }
        Button("Show Reset Dialog") { showReset = true }
    }
    .deleteConfirmation(isPresented: $showDelete, itemName: "Agent") {}
    .resetConfirmation(isPresented: $showReset, itemName: "Settings") {}
    .appScreenPadding()
}
