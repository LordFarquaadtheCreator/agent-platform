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
                        if !model.deviations.isEmpty {
                            AppText("Gallery", style: .title3)
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

    private func deviationCard(_ deviation: DeviantArtClient.Deviation) -> some View {
        AppCard {
            AppVStack(spacing: .small, alignment: .leading) {
                AppText(deviation.title, style: .headline)
                if let stats = deviation.stats {
                    AppText("\(stats.views ?? 0) views · \(stats.favourites ?? 0) favs", style: .caption, color: AppTheme.ColorToken.textSecondary)
                }
                if let published = deviation.publishedTime {
                    AppText(published, style: .caption2, color: AppTheme.ColorToken.textSecondary)
                }
            }
        }
    }
}
