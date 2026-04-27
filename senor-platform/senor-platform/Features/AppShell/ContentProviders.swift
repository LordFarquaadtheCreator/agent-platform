import SwiftUI

// MARK: - Main Content Provider Protocol

public protocol MainContentProvider {
    var section: AppSection { get }
    @ViewBuilder func content(
        using workspace: WorkspaceModel,
        router: AppRouter,
        appState: AppShellModel
    ) -> AnyView
}

// MARK: - Main Content Registry

public struct MainContentRegistry {
    private let providers: [AppSection: MainContentProvider]

    public init(providers: [MainContentProvider]) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.section, $0) })
    }

    @ViewBuilder public func view(
        for section: AppSection,
        using workspace: WorkspaceModel,
        router: AppRouter,
        appState: AppShellModel
    ) -> some View {
        providers[section]?.content(using: workspace, router: router, appState: appState) ?? AnyView(EmptyView())
    }
}

// MARK: - Inspector Content Provider Protocol

public protocol InspectorContentProvider {
    var section: AppSection { get }
    @ViewBuilder func content(
        using workspace: WorkspaceModel,
        router: AppRouter,
        appState: AppShellModel
    ) -> AnyView
}

// MARK: - Inspector Content Registry

public struct InspectorContentRegistry {
    private let providers: [AppSection: InspectorContentProvider]

    public init(providers: [InspectorContentProvider]) {
        let pairs: [(AppSection, InspectorContentProvider)] = providers.map { ($0.section, $0) }
        self.providers = Dictionary(uniqueKeysWithValues: pairs)
    }

    @ViewBuilder public func view(
        for section: AppSection,
        using workspace: WorkspaceModel,
        router: AppRouter,
        appState: AppShellModel
    ) -> some View {
        providers[section]?.content(using: workspace, router: router, appState: appState)
            ?? AnyView(AppEmptyState(
                title: "Nothing Selected",
                systemImage: AppTheme.Icon.sidebar,
                message: "Choose an item to inspect details."
            ))
    }
}
