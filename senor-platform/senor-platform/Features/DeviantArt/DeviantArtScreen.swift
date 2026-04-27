import SwiftUI

struct DeviantArtScreen: View {
    @ObservedObject var model: DeviantArtModel

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                title: "DeviantArt",
                detail: model.profile?.user.username
            )
            .padding(AppTheme.Spacing.screenPadding)

            AppDivider()

            if !model.isAuthenticated {
                Spacer()
                AppEmptyState(
                    title: "Not Connected",
                    systemImage: "paintbrush",
                    message: "DeviantArt credentials configured but not authenticated. Complete OAuth in Settings."
                )
                Spacer()
            } else if model.isLoading && model.deviations.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = model.errorMessage {
                Spacer()
                AppEmptyState(
                    title: "Error",
                    systemImage: AppTheme.Icon.exclamation,
                    message: error
                )
                Spacer()
            } else if model.profile == nil && model.deviations.isEmpty {
                Spacer()
                AppEmptyState(
                    title: "No Data",
                    systemImage: "paintbrush",
                    message: "No profile or gallery data found."
                )
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        if let profile = model.profile {
                            profileCard(profile)
                        }
                        if !model.stashItems.isEmpty {
                            AppText("Sta.sh (Unpublished)", style: .title3)
                            stashGrid(model.stashItems)
                        }
                        if !model.deviations.isEmpty {
                            AppText("Published Gallery", style: .title3)
                            deviationsGrid(model.deviations)
                        }
                    }
                    .appScreenPadding()
                }
            }
        }
        .background(AppTheme.ColorToken.chromeBackground)
        .task { await model.load() }
    }

    private func profileCard(_ profile: DeviantArtClient.UserProfile) -> some View {
        AppCard {
            AppVStack(spacing: .medium, alignment: .leading) {
                AppText(profile.user.username, style: .title2)
                if let stats = profile.stats {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.medium) {
                        AppMetricCard(
                            title: "Deviations",
                            value: "\(stats.deviations ?? 0)",
                            icon: "photo.on.rectangle.angled",
                            tint: AppTheme.ColorToken.accent
                        )
                        AppMetricCard(
                            title: "Watchers",
                            value: "\(stats.watchers ?? 0)",
                            icon: "eye",
                            tint: AppTheme.ColorToken.statusInfo
                        )
                        AppMetricCard(
                            title: "Friends",
                            value: "\(stats.friends ?? 0)",
                            icon: "person.2",
                            tint: AppTheme.ColorToken.statusSuccess
                        )
                    }
                }
            }
        }
    }

    private func deviationsGrid(_ deviations: [DeviantArtClient.Deviation]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: AppTheme.Spacing.medium) {
            ForEach(deviations) { deviation in
                deviationCard(deviation)
            }
        }
    }

    private func stashGrid(_ items: [DeviantArtClient.StashItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: AppTheme.Spacing.medium) {
            ForEach(items) { item in
                stashCard(item)
            }
        }
    }

    private func deviationCard(_ deviation: DeviantArtClient.Deviation) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                // Image Preview
                if let previewURL = deviation.previewURL {
                    AsyncImage(url: previewURL) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                                .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                                .overlay(ProgressView())
                                .frame(height: 150)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
                        case .failure:
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                                .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                                .overlay(AppIcon(AppTheme.Icon.content, size: .large, color: AppTheme.ColorToken.textSecondary))
                                .frame(height: 150)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                        .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                        .overlay(AppIcon(AppTheme.Icon.content, size: .large, color: AppTheme.ColorToken.textSecondary))
                        .frame(height: 150)
                }

                // Published Badge
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.ColorToken.statusSuccess)
                    AppText("Published", style: .caption)
                        .foregroundColor(AppTheme.ColorToken.statusSuccess)
                }

                AppText(deviation.title, style: .headline)
                    .lineLimit(1)

                if let stats = deviation.stats {
                    AppText("\(stats.views ?? 0) views · \(stats.favourites ?? 0) favs", style: .caption, color: AppTheme.ColorToken.textSecondary)
                }
                if let published = deviation.publishedTime {
                    AppText(published, style: .caption2, color: AppTheme.ColorToken.textSecondary)
                }
            }
        }
    }

    private func stashCard(_ item: DeviantArtClient.StashItem) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                // Image Preview
                if let previewURL = item.previewURL {
                    AsyncImage(url: previewURL) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                                .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                                .overlay(ProgressView())
                                .frame(height: 150)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
                        case .failure:
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                                .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                                .overlay(AppIcon(AppTheme.Icon.content, size: .large, color: AppTheme.ColorToken.textSecondary))
                                .frame(height: 150)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
                        .fill(AppTheme.ColorToken.textSecondary.opacity(0.2))
                        .overlay(AppIcon(AppTheme.Icon.content, size: .large, color: AppTheme.ColorToken.textSecondary))
                        .frame(height: 150)
                }

                // Sta.sh Status Badge
                HStack {
                    Image(systemName: "archivebox.fill")
                        .foregroundColor(AppTheme.ColorToken.statusWarning)
                    AppText("In Sta.sh", style: .caption)
                        .foregroundColor(AppTheme.ColorToken.statusWarning)
                }

                AppText(item.title, style: .headline)
                    .lineLimit(1)

                AppText("Not published yet", style: .caption, color: AppTheme.ColorToken.textSecondary)
            }
        }
    }
}
