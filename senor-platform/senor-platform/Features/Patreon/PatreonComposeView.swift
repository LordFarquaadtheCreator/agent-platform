import SwiftUI

// MARK: - Patreon Compose View
// Create or edit Patreon posts

struct PatreonComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var formViewModel: PatreonComposeViewModel

    private var isEditing: Bool { formViewModel.isEditing }

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
                        Task { await savePost() }
                    }
                    .disabled(!formViewModel.canSave)
                }
            }
        }
        .frame(minWidth: AppTheme.Layout.largeSheetWidth, maxHeight: AppTheme.Layout.mediumSheetHeight)
        .disabled(formViewModel.isSaving)
        .overlay {
            if formViewModel.isSaving {
                ProgressView(isEditing ? "Updating..." : "Creating...")
                    .padding(AppTheme.Spacing.medium)
                    .background(AppTheme.ColorToken.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
            }
        }
    }

    private var titleSection: some View {
        AppInputField(
            title: "Post Title",
            placeholder: "Enter post title",
            text: $formViewModel.title
        )
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AppInputField(
                title: "Content",
                placeholder: "Enter post content...",
                text: $formViewModel.content,
                isMultiline: true,
                height: 150
            )

            MediaPicker(
                title: "Media",
                selectedURLs: $formViewModel.mediaURLs
            )
        }
    }

    private var visibilitySection: some View {
        AppSurface(style: .card) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                AppText("Visibility", style: .headline)

                Picker("Visibility", selection: $formViewModel.isPublic) {
                    Text("Patrons Only").tag(false)
                    Text("Public").tag(true)
                }
                .pickerStyle(.segmented)

                if !formViewModel.isPublic {
                    Toggle("Paid Post", isOn: $formViewModel.isPaid)

                    if formViewModel.isPaid {
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

                if formViewModel.viewModel.tiers.isEmpty {
                    AppText("No tiers loaded", style: .body, color: AppTheme.ColorToken.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        ForEach(formViewModel.viewModel.tiers) { tier in
                            TierCheckbox(
                                tier: tier,
                                isSelected: formViewModel.selectedTiers.contains(tier.id)
                            ) {
                                if formViewModel.selectedTiers.contains(tier.id) {
                                    formViewModel.selectedTiers.remove(tier.id)
                                } else {
                                    formViewModel.selectedTiers.insert(tier.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func savePost() async {
        let success = await formViewModel.save()
        if success {
            dismiss()
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

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
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

#if DEBUG
#Preview("Patreon Compose") {
	let patreonVM = previewPatreonViewModel(postCount: 5, memberCount: 3)
	PatreonComposeView(
		formViewModel: PatreonComposeViewModel(
			viewModel: patreonVM,
			onComplete: {}
		)
	)
}
#endif
