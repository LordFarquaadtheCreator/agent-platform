import SwiftUI

struct ContentScreen: View {
    @ObservedObject var viewModel: ContentViewModel
    @ObservedObject var router: AppRouter
    @State private var searchText = ""

    var filteredItems: [ContentSummary] {
        guard !searchText.isEmpty else { return viewModel.contentItems }
        return viewModel.contentItems.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                title: "Content",
                detail: "\(viewModel.contentItems.count) generated items"
            )
            .padding(AppTheme.Spacing.screenPadding)

            AppDivider()

            // swiftlint:disable:next unlabeled_input_field
            TextField("Search content", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, AppTheme.Spacing.screenPadding)
                .padding(.vertical, AppTheme.Spacing.medium)

            if filteredItems.isEmpty {
                Spacer()
                AppEmptyState(
                    title: "No Content Yet",
                    systemImage: AppTheme.Icon.content,
                    message: "Generated content will appear here after agents complete tasks."
                )
                Spacer()
            } else {
                List(filteredItems, selection: $router.selectedContentID) { item in
                    AppListRow {
                        HStack(spacing: AppTheme.Spacing.medium) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                                AppText(item.title, style: .headline)
                                AppText(
                                    item.createdAt.formatted(.relative(presentation: .named)),
                                    style: .caption,
                                    color: AppTheme.ColorToken.textSecondary
                                )
                            }
                            Spacer()
                            AppStatusPill(
                                title: item.status.title,
                                color: StatusColor.from(item.status.rawValue).swiftUIColor
                            )
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct ContentJSONEditorSheet: View {
    @EnvironmentObject private var appState: AppShellModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ContentViewModel
    let contentId: String

    @State private var jsonText = ""
    @State private var originalJSON = ""
    @State private var isLoading = true
    @State private var changeReason = ""
    @State private var showSaveDialog = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AppText("Edit Content JSON", style: .headline)
                Spacer()
                Button("Format") {
                    if let formatted = JSONUtils.format(jsonText) {
                        jsonText = formatted
                    }
                }
                .appButtonStyle(.bordered)
                Button("Cancel") { dismiss() }
                Button("Save") {
                    showSaveDialog = true
                }
                .appButtonStyle(.borderedProminent)
                .disabled(isLoading || jsonText == originalJSON)
            }
            .padding(AppTheme.Spacing.medium)

            AppDivider()

            if isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else {
                AppInputField(
                    title: "",
                    placeholder: "",
                    text: $jsonText,
                    isMultiline: true,
                    height: 400
                )
                .padding(AppTheme.Spacing.medium)
            }
        }
        .task {
            await load()
        }
        .alert("Save Changes", isPresented: $showSaveDialog) {
            // Alert title "Save Changes" serves as the field label
            // swiftlint:disable:next unlabeled_input_field
            TextField("Change reason", text: $changeReason)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task { await save() }
            }
        } message: {
            AppText("Describe the change for version history.", style: .body)
        }
        .frame(minWidth: AppTheme.Layout.mediumSheetWidth, minHeight: AppTheme.Layout.mediumSheetHeight)
    }

    private func load() async {
        do {
            let json = try await viewModel.loadEditorJSON(contentId: contentId)
            jsonText = json
            originalJSON = json
            isLoading = false
        } catch {
            appState.errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func save() async {
        guard JSONUtils.validate(jsonText) else {
            appState.errorMessage = "JSON is invalid."
            return
        }
        do {
            try await viewModel.save(
                ContentEditRequest(
                    contentId: contentId,
                    json: jsonText,
                    changeReason: changeReason.isEmpty ? nil : changeReason,
                    editedBy: "user"
                )
            )
            dismiss()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

struct ContentVersionHistorySheet: View {
    @EnvironmentObject private var appState: AppShellModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ContentViewModel
    let contentId: String

    @State private var versions: [VersionInfo] = []
    @State private var selectedVersion: VersionInfo?
    @State private var isLoading = true
    @State private var showRestoreDialog = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AppText("Version History", style: .headline)
                Spacer()
                Button("Restore") {
                    showRestoreDialog = true
                }
                .appButtonStyle(.borderedProminent)
                .disabled(selectedVersion == nil)
                Button("Close") { dismiss() }
            }
            .padding(AppTheme.Spacing.medium)

            AppDivider()

            if isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if versions.isEmpty {
                Spacer()
                AppEmptyState(
                    title: "No Versions",
                    systemImage: "clock.arrow.circlepath",
                    message: "Version history will appear after edits are saved."
                )
                Spacer()
            } else {
                List(versions, selection: $selectedVersion) { version in
                    AppListRow {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.tightGap) {
                            AppText("Version \(version.version)", style: .headline)
                            AppText(version.description, style: .caption, color: AppTheme.ColorToken.textSecondary)
                            AppText(version.preview, style: .monospaceCaption, color: AppTheme.ColorToken.textSecondary)
                        }
                    }
                }
            }
        }
        .task {
            await load()
        }
        .alert("Restore Version", isPresented: $showRestoreDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                Task { await restore() }
            }
        } message: {
            AppText("This creates a new current version using the selected snapshot.", style: .body)
        }
        .frame(minWidth: AppTheme.Layout.minSheetWidth, minHeight: AppTheme.Layout.minSheetHeight)
    }

    private func load() async {
        do {
            versions = try await viewModel.loadHistory(contentId: contentId)
            selectedVersion = versions.first
            isLoading = false
        } catch {
            appState.errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func restore() async {
        guard let selectedVersion else { return }
        do {
            try await viewModel.restore(
                contentId: contentId,
                version: selectedVersion.version,
                changeReason: "Restored from version \(selectedVersion.version)"
            )
            dismiss()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Previews

// Note: Preview requires complex dependencies - use WorkspaceView for testing
