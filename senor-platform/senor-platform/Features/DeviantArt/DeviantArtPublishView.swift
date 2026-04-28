import SwiftUI

struct DeviantArtPublishView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.privacyMode) private var isPrivacyMode
    @ObservedObject var viewModel: DeviantArtViewModel
    let stashItem: DeviantArtClient.StashItem

    @State private var title: String = ""
    @State private var category: String = ""
    @State private var isMature = false
    @State private var matureLevel: String = ""
    @State private var allowsComments = true
    @State private var isPublishing = false

    private let categories = [
        "3d": "3D & Fractal Art",
        "admins": "Administrators",
        "advertising": "Advertising",
        "animation": "Animation & Film",
        "anime": "Anime & Manga",
        "anthro": "Anthro",
        "artisan": "Artisan Crafts",
        "cosplay": "Cosplay",
        "customization": "Customization",
        "designs": "Designs & Interfaces",
        "digitalart": "Digital Art",
        "drawings": "Drawings & Paintings",
        "fanart": "Fan Art",
        "fantasy": "Fantasy",
        "gameart": "Game Art",
        "literature": "Literature",
        "manga": "Manga",
        "photography": "Photography",
        "resources": "Resources & Stock Images",
        "sciencefiction": "Science Fiction",
        "streetart": "Street Art",
        "traditional": "Traditional Art"
    ]

    private let matureLevels = [
        "",
        "strict",
        "moderate"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    stashPreview
                    titleSection
                    categorySection
                    optionsSection
                }
                .appScreenPadding()
            }
            .background(AppTheme.ColorToken.chromeBackground)
            .navigationTitle("Publish Deviation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        performPublish()
                    }
                    .disabled(!canPublish)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            title = stashItem.title
        }
        .disabled(isPublishing)
        .overlay {
            if isPublishing {
                ProgressView("Publishing...")
                    .padding()
                    .background(AppTheme.ColorToken.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
            }
        }
        .toast(message: .init(
            get: { ToastState.shared.message },
            set: { ToastState.shared.message = $0 }
        ))
    }

    private var stashPreview: some View {
        AppSurface(style: .card) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(AppTheme.ColorToken.statusWarning)
                    AppText("Publishing from Sta.sh", style: .caption, color: AppTheme.ColorToken.textSecondary)
                }

                if let thumbURL = stashItem.previewURL {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .blur(radius: isPrivacyMode ? 20 : 0)
                                .frame(maxHeight: 150)

                        default:
                            EmptyView()
                        }
                    }
                }

                AppText(stashItem.title.isEmpty ? "Untitled" : stashItem.title, style: .headline)
            }
        }
    }

    private var titleSection: some View {
        AppInputField(
            title: "Deviation Title",
            placeholder: "Enter title for your deviation",
            text: $title
        )
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppText("Category", style: .headline)

            Picker("Category", selection: $category) {
                Text("Select a category...").tag("")
                ForEach(Array(categories.keys.sorted()), id: \.self) { key in
                    Text(categories[key] ?? key).tag(key)
                }
            }
            .pickerStyle(.menu)
            .padding(AppTheme.Spacing.small)
            .background(AppTheme.ColorToken.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))

            aiCategoryBar
        }
    }

    private var aiCategoryBar: some View {
        HStack {
            HStack(spacing: AppTheme.Spacing.xSmall) {
                Image(systemName: "sparkles")
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(AppTheme.ColorToken.accent)
                AppText("AI", style: .caption2, color: AppTheme.ColorToken.accent)
            }
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, AppTheme.Spacing.xSmall)
            .background(AppTheme.ColorToken.accent.opacity(0.1))
            .clipShape(Capsule())

            Button {
                ToastState.shared.message = "TODO: IMPLEMENT"
            } label: {
                AppText("Suggest category with AI", style: .caption, color: AppTheme.ColorToken.accent)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xSmall)
    }

    private var optionsSection: some View {
        AppSurface(style: .card) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Toggle("Mature Content", isOn: $isMature)

                if isMature {
                    Picker("Mature Level", selection: $matureLevel) {
                        Text("Default").tag("")
                        Text("Strict").tag("strict")
                        Text("Moderate").tag("moderate")
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("Allow Comments", isOn: $allowsComments)
            }
        }
    }

    private var canPublish: Bool {
        !title.isEmpty && !category.isEmpty
    }

    private func performPublish() {
        isPublishing = true
        Task {
            do {
                try await viewModel.publishFromStash(
                    stashId: stashItem.itemid,
                    title: title,
                    category: category.isEmpty ? nil : category,
                    isMature: isMature,
                    matureLevel: matureLevel.isEmpty ? nil : matureLevel,
                    allowsComments: allowsComments
                )
                await MainActor.run {
                    isPublishing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    ToastState.shared.message = "Publish failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Standard Stash Item") {
    let stashItem = DeviantArtClient.StashItem(
        itemid: "item-1",
        stackid: "stack-1",
        title: "My Artwork",
        path: nil,
        size: nil,
        fileSize: 2048000,
        status: "draft",
        thumb: nil,
        position: 1
    )
    DeviantArtPublishView(viewModel: .preview, stashItem: stashItem)
}

#Preview("Long Title") {
    let stashItem = DeviantArtClient.StashItem(
        itemid: "item-2",
        stackid: "stack-1",
        title: "This is a Very Long Title That Tests How the UI Handles Long Text in the Publish View",
        path: nil,
        size: nil,
        fileSize: 4096000,
        status: "draft",
        thumb: nil,
        position: 1
    )
    DeviantArtPublishView(viewModel: .preview, stashItem: stashItem)
}

#Preview("Empty Title") {
    let stashItem = DeviantArtClient.StashItem(
        itemid: "item-3",
        stackid: "stack-1",
        title: "",
        path: nil,
        size: nil,
        fileSize: 1024000,
        status: "draft",
        thumb: nil,
        position: 1
    )
    DeviantArtPublishView(viewModel: .preview, stashItem: stashItem)
}

#Preview("Large File") {
    let stashItem = DeviantArtClient.StashItem(
        itemid: "item-4",
        stackid: "stack-1",
        title: "High Resolution Art",
        path: nil,
        size: nil,
        fileSize: 52428800,
        status: "draft",
        thumb: nil,
        position: 1
    )
    DeviantArtPublishView(viewModel: .preview, stashItem: stashItem)
}

#Preview("Published Status") {
    let stashItem = DeviantArtClient.StashItem(
        itemid: "item-5",
        stackid: "stack-1",
        title: "Already Published",
        path: nil,
        size: nil,
        fileSize: 1024000,
        status: "published",
        thumb: nil,
        position: 1
    )
    DeviantArtPublishView(viewModel: .preview, stashItem: stashItem)
}
