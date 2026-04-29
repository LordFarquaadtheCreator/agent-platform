import SwiftUI

struct DeviantArtPublishView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.privacyMode) private var isPrivacyMode
    @StateObject var formViewModel: DeviantArtPublishViewModel

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
                        Task { await performPublish() }
                    }
                    .disabled(!formViewModel.canPublish)
                }
            }
        }
        .frame(minWidth: AppTheme.Layout.mediumSheetWidth, minHeight: AppTheme.Layout.mediumSheetHeight)
        .disabled(formViewModel.isPublishing)
        .overlay {
            if formViewModel.isPublishing {
                ProgressView("Publishing...")
                    .padding(AppTheme.Spacing.medium)
                    .background(AppTheme.ColorToken.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
            }
        }
    }

    private var stashPreview: some View {
        AppSurface(style: .card) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(AppTheme.ColorToken.statusWarning)
                    AppText("Publishing from Sta.sh", style: .caption, color: AppTheme.ColorToken.textSecondary)
                }

                if let thumbURL = formViewModel.stashItem.previewURL {
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

                AppText(formViewModel.stashItem.title.isEmpty ? "Untitled" : formViewModel.stashItem.title, style: .headline)
            }
        }
    }

    private var titleSection: some View {
        AppInputField(
            title: "Deviation Title",
            placeholder: "Enter title for your deviation",
            text: $formViewModel.title
        )
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppText("Category", style: .headline)

            Picker("Category", selection: $formViewModel.category) {
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
            .appButtonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xSmall)
    }

    private var optionsSection: some View {
        AppSurface(style: .card) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Toggle("Mature Content", isOn: $formViewModel.isMature)

                if formViewModel.isMature {
                    Picker("Mature Level", selection: $formViewModel.matureLevel) {
                        Text("Default").tag("")
                        Text("Strict").tag("strict")
                        Text("Moderate").tag("moderate")
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("Allow Comments", isOn: $formViewModel.allowsComments)
            }
        }
    }

    private func performPublish() async {
        let success = await formViewModel.publish()
        if success {
            dismiss()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("DeviantArt Publish") {
	let deviantArtVM = previewDeviantArtViewModel(deviationCount: 0)
	
	// Create StashItem via JSON decoding since it's Codable
	let jsonData = """
	{
		"itemid": "preview-stash-1",
		"stackid": "stack-1",
		"title": "Preview Stash Item",
		"path": "/path/to/file.png",
		"size": 1024000,
		"filesize": 1024000,
		"status": "draft",
		"thumb": null,
		"position": 1
	}
	""".data(using: .utf8)!
	let stashItem = try! JSONDecoder().decode(DeviantArtClient.StashItem.self, from: jsonData)
	
	DeviantArtPublishView(
		formViewModel: DeviantArtPublishViewModel(
			viewModel: deviantArtVM,
			stashItem: stashItem,
			onComplete: {}
		)
	)
}
#endif
