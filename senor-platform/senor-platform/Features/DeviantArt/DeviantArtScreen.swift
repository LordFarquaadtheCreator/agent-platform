import SwiftUI

// MARK: - Main Screen

struct DeviantArtScreen: View {
    @ObservedObject var viewModel: DeviantArtViewModel
    @State private var selectedDeviation: DeviantArtClient.Deviation?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            AppDivider()
            contentView
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task { await viewModel.load() }
        .sheet(item: $selectedDeviation) { deviation in
            DeviationDetailSheet(deviation: deviation, viewModel: viewModel)
        }
    }

    private var headerView: some View {
        HStack {
            AppSectionHeader(
                title: "DeviantArt",
                detail: viewModel.profile?.user.username
            )
            Spacer()
            if viewModel.isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, AppTheme.Spacing.small)
            }
            if let lastUpdated = viewModel.lastUpdated {
                AppText(RelativeDateFormatter.format(lastUpdated), style: .caption2, color: AppTheme.ColorToken.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.screenPadding)
    }

    @ViewBuilder
    private var contentView: some View {
        if !viewModel.isAuthenticated {
            NotConnectedView(
                title: "Not Connected",
                systemImage: "paintbrush",
                message: "DeviantArt credentials configured but not authenticated. Complete OAuth in Settings."
            )
        } else if viewModel.isLoading && viewModel.deviations.isEmpty && viewModel.profile == nil {
            LoadingStateView()
        } else if let error = viewModel.errorMessage, viewModel.profile == nil {
            ErrorStateView(message: error)
        } else if viewModel.profile == nil && viewModel.deviations.isEmpty {
            EmptyDataView(
                title: "No Data",
                systemImage: "paintbrush",
                message: "No profile or gallery data found."
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    if let profile = viewModel.profile {
                        ProfileCard(profile: profile)
                    }
                    if !viewModel.stashStacks.isEmpty {
                        StashSection(stacks: viewModel.stashStacks)
                    }
                    if !viewModel.deviations.isEmpty {
                        GallerySection(
                            deviations: viewModel.deviations,
                            onSelect: { selectedDeviation = $0 }
                        )
                    }
                }
                .appScreenPadding()
            }
        }
    }
}

// MARK: - Content Views

private struct ProfileCard: View {
    let profile: DeviantArtClient.UserProfile

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                AvatarView(urlString: profile.user.usericon)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    AppText(profile.user.username, style: .title2)
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
}

private struct AvatarView: View {
    let urlString: String?

    var body: some View {
        Group {
            if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                            .overlay(ProgressView().scaleEffect(0.6))

                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)

                    case .failure:
                        placeholder

                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
            .frame(width: 80, height: 80)
            .overlay(Image(systemName: "person.fill").foregroundColor(AppTheme.ColorToken.textSecondary))
    }
}

private struct StashSection: View {
    let stacks: [DeviantArtClient.StashStack]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AppText("Sta.sh Stacks", style: .title3)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: AppTheme.Spacing.medium) {
                ForEach(stacks) { stack in
                    StashStackCard(stack: stack)
                }
            }
        }
    }
}

private struct GallerySection: View {
    let deviations: [DeviantArtClient.Deviation]
    let onSelect: (DeviantArtClient.Deviation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AppText("Published Gallery", style: .title3)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: AppTheme.Spacing.medium) {
                ForEach(deviations) { deviation in
                    DeviationCard(deviation: deviation)
                        .onTapGesture { onSelect(deviation) }
                }
            }
        }
    }
}

// MARK: - Card Views

private struct DeviationCard: View {
    let deviation: DeviantArtClient.Deviation

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                ImageSection(deviation: deviation)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    StatusRow(deviation: deviation)
                    AppText(deviation.title, style: .headline)
                        .lineLimit(1)
                    if let stats = deviation.stats {
                        StatsRow(stats: stats)
                    }
                    if let published = deviation.publishedTime {
                        AppText(RelativeDateFormatter.format(unixTime: published), style: .caption2, color: AppTheme.ColorToken.textSecondary)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.small)
                .padding(.bottom, AppTheme.Spacing.small)
            }
        }
    }
}

private struct ImageSection: View {
    let deviation: DeviantArtClient.Deviation

    var body: some View {
        ZStack(alignment: .topLeading) {
            DeviationImage(deviation: deviation)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
            if let category = deviation.category {
                CategoryBadge(category: category)
                    .padding([.top, .leading], AppTheme.Spacing.small)
            }
        }
    }
}

private struct DeviationImage: View {
    let deviation: DeviantArtClient.Deviation

    var body: some View {
        Group {
            if let previewURL = deviation.previewURL {
                AsyncImage(url: previewURL) { phase in
                    switch phase {
                    case .empty:
                        placeholder

                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)

                    case .failure:
                        placeholder

                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
            .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
            .overlay(ProgressView())
    }
}

private struct StatusRow: View {
    let deviation: DeviantArtClient.Deviation

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.ColorToken.statusSuccess)
                .font(.caption)
            AppText("Published", style: .caption)
                .foregroundColor(AppTheme.ColorToken.statusSuccess)
            Spacer()
            if deviation.allowsComments == true {
                Image(systemName: "bubble.right.fill")
                    .foregroundColor(AppTheme.ColorToken.statusInfo)
                    .font(.caption2)
            }
        }
    }
}

private struct StatsRow: View {
    let stats: DeviantArtClient.Deviation.Stats

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            StatItem(icon: "eye", value: stats.views ?? 0)
            StatItem(icon: "star.fill", value: stats.favourites ?? 0)
            StatItem(icon: "bubble.right", value: stats.comments ?? 0)
            StatItem(icon: "arrow.down.circle", value: stats.downloads ?? 0)
        }
        .font(.caption)
        .foregroundColor(AppTheme.ColorToken.textSecondary)
    }
}

private struct StashStackCard: View {
    let stack: DeviantArtClient.StashStack

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                if let items = stack.items, !items.isEmpty {
                    ThumbnailGrid(items: items.prefix(4))
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
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
                if let items = stack.items {
                    StashStatusRow(items: items)
                }
            }
            .padding(AppTheme.Spacing.small)
        }
    }
}

private struct StashStatusRow: View {
    let items: [DeviantArtClient.StashItem]

    var body: some View {
        let publishedCount = items.filter { $0.isPublished }.count
        let unpublishedCount = items.count - publishedCount
        let totalSize = items.compactMap { $0.fileSize }.reduce(0, +)

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                AppText("\(items.count) items", style: .caption, color: AppTheme.ColorToken.textSecondary)
                if unpublishedCount > 0 {
                    AppText("· \(unpublishedCount) unpublished", style: .caption, color: AppTheme.ColorToken.statusWarning)
                }
                if publishedCount > 0 {
                    AppText("· \(publishedCount) published", style: .caption, color: AppTheme.ColorToken.statusSuccess)
                }
            }
            if totalSize > 0 {
                AppText(formatBytes(totalSize), style: .caption2, color: AppTheme.ColorToken.textSecondary)
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private struct ThumbnailGrid: View {
    let items: ArraySlice<DeviantArtClient.StashItem>
    private let columns: [DeviantArtClient.StashItem]

    init(items: ArraySlice<DeviantArtClient.StashItem>) {
        self.items = items
        self.columns = Array(items.prefix(4))
    }

    var body: some View {
        Group {
            switch columns.count {
            case 1:
                stashThumbnail(columns[0])

            case 2:
                HStack(spacing: 2) {
                    stashThumbnail(columns[0])
                    stashThumbnail(columns[1])
                }

            case 3:
                HStack(spacing: 2) {
                    stashThumbnail(columns[0])
                    VStack(spacing: 2) {
                        stashThumbnail(columns[1])
                        stashThumbnail(columns[2])
                    }
                }

            default:
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        stashThumbnail(columns[0])
                        stashThumbnail(columns[1])
                    }
                    HStack(spacing: 2) {
                        stashThumbnail(columns[2])
                        stashThumbnail(columns[3])
                    }
                }
            }
        }
    }

    private func stashThumbnail(_ item: DeviantArtClient.StashItem) -> some View {
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
}

// MARK: - Previews
#Preview {
    DeviantArtScreen(viewModel: DeviantArtViewModel.preview)
}
