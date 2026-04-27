import SwiftUI

struct DeviantArtScreen: View {
    @ObservedObject var model: DeviantArtModel
    @State private var selectedDeviation: DeviantArtClient.Deviation?

    var body: some View {
        VStack(spacing: 0) {
            headerView

            AppDivider()

            contentView
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task { await model.load() }
        .sheet(item: $selectedDeviation) { deviation in
            DeviationDetailSheet(deviation: deviation, model: model)
        }
    }

    private var headerView: some View {
        HStack {
            AppSectionHeader(
                title: "DeviantArt",
                detail: model.profile?.user.username
            )

            Spacer()

            if model.isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, AppTheme.Spacing.small)
            }

            if let lastUpdated = model.lastUpdated {
                AppText(RelativeDateFormatter.format(lastUpdated), style: .caption2, color: AppTheme.ColorToken.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.screenPadding)
    }

    @ViewBuilder
    private var contentView: some View {
        if !model.isAuthenticated {
            notConnectedView
        } else if model.isLoading && model.deviations.isEmpty && model.profile == nil {
            loadingView
        } else if let error = model.errorMessage, model.profile == nil {
            errorView(error)
        } else if model.profile == nil && model.deviations.isEmpty {
            emptyView
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    if let profile = model.profile {
                        profileCard(profile)
                    }

                    if !model.stashStacks.isEmpty {
                        stashSection
                    }

                    if !model.deviations.isEmpty {
                        gallerySection
                    }
                }
                .appScreenPadding()
            }
        }
    }

    private var notConnectedView: some View {
        VStack {
            Spacer()
            AppEmptyState(
                title: "Not Connected",
                systemImage: "paintbrush",
                message: "DeviantArt credentials configured but not authenticated. Complete OAuth in Settings."
            )
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack {
            Spacer()
            AppEmptyState(
                title: "Error",
                systemImage: AppTheme.Icon.exclamation,
                message: error
            )
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            AppEmptyState(
                title: "No Data",
                systemImage: "paintbrush",
                message: "No profile or gallery data found."
            )
            Spacer()
        }
    }

    private var stashSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AppText("Sta.sh Stacks", style: .title3)
            stashStacksGrid(model.stashStacks)
        }
    }

    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AppText("Published Gallery", style: .title3)
            deviationsGrid(model.deviations)
        }
    }

    private func profileCard(_ profile: DeviantArtClient.UserProfile) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                // Avatar
                avatarView(for: profile.user.usericon)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    // Username
                    AppText(profile.user.username, style: .title2)

                    // Stats
                    if let stats = profile.stats {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: AppTheme.Spacing.small) {
                            StatPill(title: "Deviations", value: stats.deviations ?? 0, icon: "photo")
                            StatPill(title: "Watchers", value: stats.watchers ?? 0, icon: "eye")
                            StatPill(title: "Friends", value: stats.friends ?? 0, icon: "person.2")
                        }
                        .padding(.top, AppTheme.Spacing.small)
                    }
                }
            }
        }
    }

    private func avatarView(for urlString: String?) -> some View {
        Group {
            if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                            .overlay(ProgressView().scaleEffect(0.6))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Circle()
                            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                            .overlay(Image(systemName: "person.fill").foregroundColor(AppTheme.ColorToken.textSecondary))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(Image(systemName: "person.fill").foregroundColor(AppTheme.ColorToken.textSecondary))
            }
        }
    }

    private func deviationsGrid(_ deviations: [DeviantArtClient.Deviation]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: AppTheme.Spacing.medium) {
            ForEach(deviations) { deviation in
                deviationCard(deviation)
                    .onTapGesture {
                        selectedDeviation = deviation
                    }
            }
        }
    }

    private func stashStacksGrid(_ stacks: [DeviantArtClient.StashStack]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: AppTheme.Spacing.medium) {
            ForEach(stacks) { stack in
                stashStackCard(stack)
            }
        }
    }

    private func deviationCard(_ deviation: DeviantArtClient.Deviation) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                // Image section with overlays
                imageSection(for: deviation)

                // Content
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    // Published Badge
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.ColorToken.statusSuccess)
                            .font(.caption)
                        AppText("Published", style: .caption)
                            .foregroundColor(AppTheme.ColorToken.statusSuccess)

                        Spacer()

                        // Comments indicator
                        if deviation.allowsComments == true {
                            Image(systemName: "bubble.right.fill")
                                .foregroundColor(AppTheme.ColorToken.statusInfo)
                                .font(.caption2)
                        }
                    }

                    // Title
                    AppText(deviation.title, style: .headline)
                        .lineLimit(1)

                    // Full stats
                    if let stats = deviation.stats {
                        fullStatsRow(stats: stats)
                    }

                    // Date
                    if let published = deviation.publishedTime {
                        AppText(RelativeDateFormatter.format(unixTime: published), style: .caption2, color: AppTheme.ColorToken.textSecondary)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.small)
                .padding(.bottom, AppTheme.Spacing.small)
            }
        }
    }

    private func imageSection(for deviation: DeviantArtClient.Deviation) -> some View {
        ZStack(alignment: .topLeading) {
            // Base image
            deviationImage(for: deviation)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))


            // Category badge
            if let category = deviation.category {
                CategoryBadge(category: category)
                    .padding([.top, .leading], AppTheme.Spacing.small)
            }
        }
    }

    private func deviationImage(for deviation: DeviantArtClient.Deviation) -> some View {
        Group {
            if let previewURL = deviation.previewURL {
                AsyncImage(url: previewURL) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderImage
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                placeholderImage
            }
        }
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
            .overlay(AppIcon(AppTheme.Icon.content, size: .large, color: AppTheme.ColorToken.textSecondary))
    }

    private func fullStatsRow(stats: DeviantArtClient.Deviation.Stats) -> some View {
        HStack(spacing: AppTheme.Spacing.small) {
            StatItem(icon: "eye", value: stats.views ?? 0)
            StatItem(icon: "heart", value: stats.favourites ?? 0)
            StatItem(icon: "bubble.right", value: stats.comments ?? 0)
            StatItem(icon: "arrow.down.circle", value: stats.downloads ?? 0)
        }
        .font(.caption)
        .foregroundColor(AppTheme.ColorToken.textSecondary)
    }

    private func stashStackCard(_ stack: DeviantArtClient.StashStack) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                // Thumbnail grid preview
                if let items = stack.items, !items.isEmpty {
                    thumbnailGrid(for: items.prefix(4))
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }

                // Badge
                HStack {
                    Image(systemName: "archivebox.fill")
                        .foregroundColor(AppTheme.ColorToken.statusWarning)
                        .font(.caption)
                    AppText("Sta.sh Stack", style: .caption)
                        .foregroundColor(AppTheme.ColorToken.statusWarning)

                    Spacer()
                }

                AppText(stack.title ?? "Untitled Stack", style: .headline)
                    .lineLimit(1)

                // Item count and status summary
                if let items = stack.items {
                    let publishedCount = items.filter { $0.isPublished }.count
                    let unpublishedCount = items.count - publishedCount

                    HStack {
                        AppText("\(items.count) items", style: .caption, color: AppTheme.ColorToken.textSecondary)

                        if unpublishedCount > 0 {
                            AppText("· \(unpublishedCount) unpublished", style: .caption, color: AppTheme.ColorToken.statusWarning)
                        }

                        if publishedCount > 0 {
                            AppText("· \(publishedCount) published", style: .caption, color: AppTheme.ColorToken.statusSuccess)
                        }
                    }

                    // Total size
                    let totalSize = items.compactMap { $0.fileSize }.reduce(0, +)
                    if totalSize > 0 {
                        AppText(formatBytes(totalSize), style: .caption2, color: AppTheme.ColorToken.textSecondary)
                    }
                }
            }
            .padding(AppTheme.Spacing.small)
        }
    }

    private func thumbnailGrid(for items: ArraySlice<DeviantArtClient.StashItem>) -> some View {
        let columns = Array(items.prefix(4))
        return Group {
            if columns.count == 1 {
                stashThumbnail(for: columns[0])
            } else if columns.count == 2 {
                HStack(spacing: 2) {
                    stashThumbnail(for: columns[0])
                    stashThumbnail(for: columns[1])
                }
            } else if columns.count == 3 {
                HStack(spacing: 2) {
                    stashThumbnail(for: columns[0])
                    VStack(spacing: 2) {
                        stashThumbnail(for: columns[1])
                        stashThumbnail(for: columns[2])
                    }
                }
            } else {
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        stashThumbnail(for: columns[0])
                        stashThumbnail(for: columns[1])
                    }
                    HStack(spacing: 2) {
                        stashThumbnail(for: columns[2])
                        stashThumbnail(for: columns[3])
                    }
                }
            }
        }
    }

    private func stashThumbnail(for item: DeviantArtClient.StashItem) -> some View {
        Group {
            if let thumbURL = item.previewURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.gray.opacity(0.3)
                    }
                }
            } else {
                Color.gray.opacity(0.3)
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Supporting Views

struct CategoryBadge: View {
    let category: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .font(.caption2)
            Text(category.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.ColorToken.accent.opacity(0.9))
        .foregroundColor(.white)
        .clipShape(Capsule())
    }
}

struct StatPill: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.ColorToken.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct StatItem: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            if value > 0 {
                Text("\(value)")
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Detail Sheet

struct DeviationDetailSheet: View {
    let deviation: DeviantArtClient.Deviation
    @ObservedObject var model: DeviantArtModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    // Full image
                    fullImageSection

                    // Title and badges
                    titleSection

                    // Description (if metadata loaded)
                    descriptionSection

                    // Tags (if metadata loaded)
                    tagsSection

                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Deviation Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await model.loadMetadata(for: deviation.id)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private var fullImageSection: some View {
        Group {
            if let previewURL = deviation.previewURL {
                AsyncImage(url: previewURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
                    default:
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(ProgressView())
                    }
                }
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppText(deviation.title, style: .title2)

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.ColorToken.statusSuccess)
                AppText("Published", style: .body)
                    .foregroundColor(AppTheme.ColorToken.statusSuccess)

                if let category = deviation.category {
                    Text("·")
                    CategoryBadge(category: category)
                }
            }

            if let stats = deviation.stats {
                HStack(spacing: AppTheme.Spacing.medium) {
                    Label("\(stats.views ?? 0)", systemImage: "eye")
                    Label("\(stats.favourites ?? 0)", systemImage: "heart")
                    Label("\(stats.comments ?? 0)", systemImage: "bubble.right")
                    Label("\(stats.downloads ?? 0)", systemImage: "arrow.down.circle")
                }
                .foregroundColor(AppTheme.ColorToken.textSecondary)
            }

            if let published = deviation.publishedTime {
                AppText("Published \(RelativeDateFormatter.format(unixTime: published))", style: .caption, color: AppTheme.ColorToken.textSecondary)
            }
        }
    }

    private var descriptionSection: some View {
        Group {
            if let metadata = model.deviationMetadata[deviation.id],
               let description = metadata.description,
               !description.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    AppText("Description", style: .title3)
                    Text(description)
                        .font(.body)
                        .foregroundColor(AppTheme.ColorToken.textPrimary)
                }
            }
        }
    }

    private var tagsSection: some View {
        Group {
            if let metadata = model.deviationMetadata[deviation.id],
               let tags = metadata.tags,
               !tags.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    AppText("Tags", style: .title3)
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.tagName) { tag in
                            TagPill(name: tag.tagName)
                        }
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            if let url = URL(string: deviation.url) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open on DeviantArt")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.ColorToken.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.control))
                }
                .buttonStyle(.plain)
            }

            if let metadata = model.deviationMetadata[deviation.id],
               let license = metadata.license {
                AppText("License: \(license)", style: .caption, color: AppTheme.ColorToken.textSecondary)
            }
        }
    }
}

struct TagPill: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppTheme.ColorToken.textSecondary.opacity(0.15))
            .foregroundColor(AppTheme.ColorToken.textPrimary)
            .clipShape(Capsule())
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - String Extension

private extension String {
    var capitalized: String {
        prefix(1).uppercased() + dropFirst().lowercased()
    }
}
