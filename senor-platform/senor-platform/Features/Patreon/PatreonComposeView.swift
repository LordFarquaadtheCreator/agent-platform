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
    @State private var isSaving = false
    
    private var isEditing: Bool { post != nil }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    titleSection
                    contentSection
                    visibilitySection
                    tierSection
                }
                .appScreenPadding()
            }
            .background(AppTheme.ColorToken.chromeBackground)
            .navigationTitle(isEditing ? "Edit Post" : "New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePost()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 600)
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
            }
        }
    }
    
    private var titleSection: some View {
        AIHelperField(
            title: "Post Title",
            placeholder: "Enter post title",
            text: $title
        )
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack {
                AppText("Content", style: .headline)
                Spacer()
                Picker("Format", selection: .constant("markdown")) {
                    Text("Markdown").tag("markdown")
                    Text("HTML").tag("html")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            TextEditor(text: $content)
                .font(AppTheme.Typography.body)
                .frame(minHeight: 200)
                .padding(AppTheme.Spacing.small)
                .background(AppTheme.ColorToken.sectionBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
            
            aiContentBar
        }
    }
    
    private var aiContentBar: some View {
        HStack {
            HStack(spacing: AppTheme.Spacing.xSmall) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.ColorToken.accent)
                AppText("AI", style: .caption2, color: AppTheme.ColorToken.accent)
            }
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, AppTheme.Spacing.xSmall)
            .background(AppTheme.ColorToken.accent.opacity(0.1))
            .clipShape(Capsule())
            
            Button {
                ToastManager.shared.show(message: "TODO: IMPLEMENT")
            } label: {
                AppText("Generate content with AI", style: .caption, color: AppTheme.ColorToken.accent)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                ToastManager.shared.show(message: "TODO: IMPLEMENT")
            } label: {
                AppText("Improve with AI", style: .caption, color: AppTheme.ColorToken.accent)
            }
            .buttonStyle(.plain)
            .disabled(content.isEmpty)
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .background(AppTheme.ColorToken.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
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
                        AppText("Paid posts are only visible to paying patrons", style: .caption, color: AppTheme.ColorToken.textSecondary)
                    } else {
                        AppText("Free posts are visible to all patrons (including free tier)", style: .caption, color: AppTheme.ColorToken.textSecondary)
                    }
                }
            }
        }
    }
    
    private var tierSection: some View {
        AppSurface(style: .card) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack {
                    AppText("Tiers", style: .headline)
                    Spacer()
                    
                    Button {
                        ToastManager.shared.show(message: "TODO: IMPLEMENT")
                    } label: {
                        HStack(spacing: AppTheme.Spacing.xSmall) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            AppText("Suggest tiers", style: .caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.ColorToken.accent)
                }
                
                AppText("Select which tiers can see this post", style: .caption, color: AppTheme.ColorToken.textSecondary)
                
                if viewModel.campaign?.relationships?.tiers?.data?.isEmpty ?? true {
                    AppText("No tiers available", style: .body, color: AppTheme.ColorToken.textSecondary)
                } else {
                    tierList
                }
            }
        }
    }
    
    private var tierList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            ForEach(viewModel.campaign?.relationships?.tiers?.data ?? [], id: \.id) { tier in
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
                    ToastManager.shared.show(message: "Failed: \(error.localizedDescription)")
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
                        AppText("$\(Double(cents) / 100, specifier: "%.2f")/month", style: .caption, color: AppTheme.ColorToken.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(AppTheme.Spacing.small)
            .background(isSelected ? AppTheme.ColorToken.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        }
        .buttonStyle(.plain)
    }
}
