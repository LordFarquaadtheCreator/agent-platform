//
//  JSONEditorView.swift
//  senor-platform
//

import SwiftUI

struct JSONEditorView: View {
    let contentId: String
    @Environment(\.dismiss) private var dismiss
    @State private var jsonText = ""
    @State private var originalJSON = ""
    @State private var hasChanges = false
    @State private var showValidationError = false
    @State private var validationError = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var changeReason = ""
    @State private var showSaveDialog = false

    @State private var versioningService: ContentVersioningService?
    @State private var contentRepository: GeneratedContentRepository?
    private let logger = AppLogger.ui

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Edit Content JSON")
                    .font(.headline)

                Spacer()

                if hasChanges {
                    Text("Modified")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }

                Button("Format") {
                    formatJSON()
                }
                .buttonStyle(.bordered)

                Button("Validate") {
                    validateJSON()
                }
                .buttonStyle(.bordered)

                Divider()
                    .frame(height: 20)

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    showSaveDialog = true
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges || isLoading)
            }
            .padding()

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else {
                // Editor
                TextEditor(text: $jsonText)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: jsonText) { _, newValue in
                        hasChanges = newValue != originalJSON
                        showValidationError = false
                    }
            }
        }
        .task {
            await resolveServices()
            loadContent()
        }
        .alert("Validation Error", isPresented: $showValidationError) {
            Button("OK") {}
        } message: {
            Text(validationError)
        }
        .alert("Save Changes", isPresented: $showSaveDialog) {
            TextField("Change reason (optional)", text: $changeReason)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveChanges()
            }
        } message: {
            Text("Describe what changed (optional)")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func resolveServices() async {
        versioningService = await sharedContainer.resolveOptional(ContentVersioningService.self)
        contentRepository = await sharedContainer.resolveOptional(GeneratedContentRepository.self)
    }

    private func loadContent() {
        Task {
            guard let repository = contentRepository else {
                await MainActor.run {
                    errorMessage = "Services not available"
                    isLoading = false
                }
                return
            }
            do {
                guard let content = try await repository.getById(id: contentId) else {
                    await MainActor.run {
                        errorMessage = "Content not found"
                        isLoading = false
                    }
                    return
                }

                let json = content.generatedContentJson

                // Format it nicely
                if let formatted = JSONUtils.format(json) {
                    await MainActor.run {
                        jsonText = formatted
                        originalJSON = formatted
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        jsonText = json
                        originalJSON = json
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load content: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func formatJSON() {
        guard let formatted = JSONUtils.format(jsonText) else {
            validationError = "Invalid JSON - cannot format"
            showValidationError = true
            return
        }
        jsonText = formatted
    }

    private func validateJSON() {
        guard JSONUtils.validate(jsonText) else {
            validationError = "Invalid JSON syntax"
            showValidationError = true
            return
        }

        validationError = "JSON is valid!"
        showValidationError = true
    }

    private func saveChanges() {
        guard let service = versioningService else {
            errorMessage = "Services not available"
            return
        }
        guard JSONUtils.validate(jsonText) else {
            validationError = "Cannot save invalid JSON"
            showValidationError = true
            return
        }

        isLoading = true

        Task {
            do {
                _ = try await service.editContent(
                    contentId: contentId,
                    newContentJson: jsonText,
                    changeReason: changeReason.isEmpty ? nil : changeReason,
                    editedBy: "user"
                )

                logger.info("Saved changes to content: \(contentId)")

                await MainActor.run {
                    isLoading = false
                    originalJSON = jsonText
                    hasChanges = false
                    dismiss()
                    EventBus.shared.refreshAllData()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Version History View

struct VersionHistoryView: View {
    let contentId: String
    @Environment(\.dismiss) private var dismiss
    @State private var versions: [VersionInfo] = []
    @State private var selectedVersion: VersionInfo?
    @State private var comparisonMode = false
    @State private var compareFrom: VersionInfo?
    @State private var compareTo: VersionInfo?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showRestoreConfirmation = false

    private let versioningService = sharedContainer.resolveOrCrash(ContentVersioningService.self)
    private let logger = AppLogger.ui

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Version History")
                    .font(.headline)

                Spacer()

                Toggle("Compare Mode", isOn: $comparisonMode)

                Divider()
                    .frame(height: 20)

                Button("Restore Selected") {
                    showRestoreConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedVersion == nil || isLoading)

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle")
                Text(error)
                    .foregroundStyle(.secondary)
            } else {
                // Content
                HStack(spacing: 0) {
                    // Version List
                    List(selection: $selectedVersion) {
                        ForEach(versionItems) { item in
                            VersionRow(
                                version: item,
                                isCompareSource: compareFrom?.version == item.version,
                                isCompareTarget: compareTo?.version == item.version,
                                comparisonMode: comparisonMode
                            )
                            .tag(item)
                            .onTapGesture {
                                if comparisonMode {
                                    handleComparisonSelection(item)
                                } else {
                                    selectedVersion = item
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(width: 250)

                    Divider()

                    // Preview/Compare Area
                    Group {
                        if comparisonMode && compareFrom != nil && compareTo != nil {
                            VersionComparisonView(fromVersion: compareFrom!, toVersion: compareTo!)
                        } else if let selected = selectedVersion {
                            VersionPreviewView(version: selected)
                        } else {
                            ContentUnavailableView(
                                "Select a version",
                                systemImage: "clock.arrow.circlepath"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await loadVersions()
        }
        .alert("Restore Version", isPresented: $showRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                restoreSelectedVersion()
            }
        } message: {
            Text("Are you sure you want to restore version \(selectedVersion?.version ?? 0)? This will create a new version with the restored content.")
        }
    }

    private var versionItems: [VersionInfo] {
        versions
    }

    private func loadVersions() async {
        isLoading = true
        do {
            let history = try await versioningService.getVersionHistory(contentId: contentId)

            // Get current version info
            if let current = try await versioningService.getCurrentVersion(contentId: contentId) {
                var allVersions = history
                // Mark current version
                for i in 0..<allVersions.count {
                    if allVersions[i].version == current.version {
                        // Already in list
                    }
                }
            }

            await MainActor.run {
                self.versions = history
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func handleComparisonSelection(_ version: VersionInfo) {
        if compareFrom == nil {
            compareFrom = version
        } else if compareTo == nil && version.version != compareFrom?.version {
            compareTo = version
        } else {
            compareFrom = version
            compareTo = nil
        }
    }

    private func restoreSelectedVersion() {
        guard let version = selectedVersion else { return }

        isLoading = true
        Task {
            do {
                _ = try await versioningService.restoreVersion(
                    contentId: contentId,
                    targetVersion: version.version
                )

                logger.info("Restored version \(version.version) for content \(contentId)")

                await loadVersions()

                await MainActor.run {
                    EventBus.shared.refreshAllData()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to restore: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct VersionRow: View {
    let version: VersionInfo
    let isCompareSource: Bool
    let isCompareTarget: Bool
    let comparisonMode: Bool

    var body: some View {
        HStack(spacing: 8) {
            if comparisonMode {
                ZStack {
                    Circle()
                        .fill(isCompareSource ? Color.blue : (isCompareTarget ? Color.green : Color.gray.opacity(0.3)))
                        .frame(width: 24, height: 24)

                    if isCompareSource {
                        Text("A")
                            .font(.caption)
                            .foregroundStyle(.white)
                    } else if isCompareTarget {
                        Text("B")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("v\(version.version)")
                        .font(.headline)
                }

                Text(version.changeReason ?? "No description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack {
                    Text("By \(version.editedBy)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(version.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct VersionPreviewView: View {
    let version: VersionInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Version \(version.version) Preview")
                    .font(.headline)
                Spacer()
                Text(version.createdAt.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                Text(version.preview)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
    }
}

struct VersionComparisonView: View {
    let fromVersion: VersionInfo
    let toVersion: VersionInfo

    var body: some View {
        HStack(spacing: 0) {
            // From Version
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Version \(fromVersion.version)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Spacer()
                }
                .padding()

                Divider()

                ScrollView {
                    Text(fromVersion.preview)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // To Version
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Version \(toVersion.version)")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Spacer()
                }
                .padding()

                Divider()

                ScrollView {
                    Text(toVersion.preview)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("JSON Editor - Empty") {
    JSONEditorView(contentId: "test")
        .frame(width: 600, height: 400)
}

#Preview("JSON Editor - With Content") {
    JSONEditorView(contentId: "test")
        .frame(width: 600, height: 400)
}

#Preview("Version History - Empty") {
    VersionHistoryView(contentId: "test")
        .frame(width: 700, height: 500)
}

#Preview("Version History - With Versions") {
    VersionHistoryView(contentId: "test")
        .frame(width: 700, height: 500)
}

#Preview("Dark Mode") {
    JSONEditorView(contentId: "test")
        .preferredColorScheme(.dark)
        .frame(width: 600, height: 400)
}
