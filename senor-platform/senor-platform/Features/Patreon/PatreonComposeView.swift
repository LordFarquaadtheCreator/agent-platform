import SwiftUI

// MARK: - Patreon Compose View
// Create or edit Patreon posts

struct PatreonComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PatreonViewModel
    let post: PatreonPost? // nil for new post

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isPaid = true
    @State private var isPublic = false
    @State private var selectedTiers: Set<String> = []
    @State private var mediaURLs: [URL] = []
    @State private var isSaving = false

    private var isEditing: Bool { post != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    titleSection
                    contentSection

					HStack(alignment: .top) {
						visibilitySection
							.frame(maxHeight: .infinity, alignment: .top)
						tierSection
							.frame(maxHeight: .infinity, alignment: .top)
					}
                }
                .appScreenPadding()
            }
            .background(AppTheme.ColorToken.chromeBackground)
            .navigationTitle(isEditing ? "Edit Post" : "New Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Post") {
                        savePost()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 800, maxHeight: 500)
        .disabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView(isEditing ? "Updating..." : "Creating...")
                    .padding()
                    .background(AppTheme.ColorToken.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
            }
        }
        .onAppear {
            if let post = post {
                title = post.attributes.title ?? ""
                content = post.attributes.content ?? ""
                isPaid = post.attributes.isPaid ?? true
                isPublic = post.attributes.isPublic ?? false
                if let tierData = post.relationships?.tiers?.data {
                    selectedTiers = Set(tierData.map(\.id))
                }
            }
        }
        .toast(message: .init(
            get: { ToastState.shared.message },
            set: { ToastState.shared.message = $0 }
        ))
    }

    private var titleSection: some View {
        AppInputField(
            title: "Post Title",
            placeholder: "Enter post title",
            text: $title
        )
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AppInputField(
                title: "Content",
                placeholder: "Enter post content...",
                text: $content,
                isMultiline: true,
                height: 150
            )

            MediaPicker(
                title: "Media",
                selectedURLs: $mediaURLs
            )
        }
    }

    private var visibilitySection: some View {
        AppSurface(style: .card) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                AppText("Visibility", style: .headline)

                Picker("Visibility", selection: $isPublic) {
                    Text("Patrons Only").tag(false)
                    Text("Public").tag(true)
                }
                .pickerStyle(.segmented)

                if !isPublic {
                    Toggle("Paid Post", isOn: $isPaid)

                    if isPaid {
                        AppText(
                            "Paid posts are only visible to paying patrons",
                            style: .caption,
                            color: AppTheme.ColorToken.textSecondary
                        )
                    } else {
                        AppText(
                            "Free posts are visible to all patrons (including free tier)",
                            style: .caption,
                            color: AppTheme.ColorToken.textSecondary
                        )
                    }
                }
            }
        }
    }

    private var tierSection: some View {
        AppSurface(style: .card) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
				AppText("Tiers", style: .headline)

                AppText(
                    "Select which tiers can see this post",
                    style: .caption,
                    color: AppTheme.ColorToken.textSecondary
                )

                if viewModel.tiers.isEmpty {
                    AppText("No tiers loaded", style: .body, color: AppTheme.ColorToken.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        ForEach(viewModel.tiers) { tier in
                            TierCheckbox(
                                tier: tier,
                                isSelected: selectedTiers.contains(tier.id)
                            ) {
                                if selectedTiers.contains(tier.id) {
                                    selectedTiers.remove(tier.id)
                                } else {
                                    selectedTiers.insert(tier.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        !title.isEmpty && !content.isEmpty
    }

    private func savePost() {
        isSaving = true
        Task {
            do {
                if isEditing, let post = post {
                    try await viewModel.updatePost(
                        postId: post.id,
                        title: title,
                        content: content,
                        isPaid: isPaid,
                        isPublic: isPublic
                    )
                } else {
                    try await viewModel.createPost(
                        title: title,
                        content: content,
                        isPaid: isPaid,
                        isPublic: isPublic,
                        tiers: Array(selectedTiers)
                    )
                }
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    ToastState.shared.message = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Tier Checkbox

private struct TierCheckbox: View {
    let tier: PatreonTier
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    AppText(tier.attributes.title, style: .body)
                    if let cents = tier.attributes.amountCents {
                        let price = String(format: "$%.2f/month", Double(cents) / 100)
                        AppText(price, style: .caption, color: AppTheme.ColorToken.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(AppTheme.Spacing.small)
            .background(isSelected ? AppTheme.ColorToken.accent.opacity(0.1) : AppTheme.ColorToken.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        }
        .appButtonStyle(.plain)
    }
}

#Preview {
    PatreonComposeView(viewModel: .preview, post: nil)
}
