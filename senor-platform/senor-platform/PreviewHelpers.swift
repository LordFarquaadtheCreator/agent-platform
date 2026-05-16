#if DEBUG
import SwiftUI
import Combine

// MARK: - DeviantArt Preview Helper

@MainActor
public func previewDeviantArtViewModel(
	deviationCount: Int = 5,
	stashCount: Int = 2,
	isAuthenticated: Bool = true,
	isLoading: Bool = false,
	isRefreshing: Bool = false,
	errorMessage: String? = nil
) -> DeviantArtViewModel {
	let viewModel = DeviantArtViewModel(
		client: nil,
		settingsService: SettingsService(),
		cacheService: nil
	)
	let profile = isAuthenticated ? UserProfile(
		user: UserProfile.UserInfo(
			userid: "123",
			username: "mockartist",
			usericon: "https://example.com/icon.png",
			type: "regular"
		),
		stats: UserProfile.UserStats(watchers: 150, friends: 23, deviations: 42)
	) : nil
	let deviations = isAuthenticated ? (0..<deviationCount).map { i in
		Deviation(
			deviationid: "dev-\(i)",
			url: "https://deviantart.com/art/\(i)",
			title: "Deviation \(i + 1)",
			category: "Digital Art",
			author: nil,
			stats: Deviation.Stats(views: 100 + i * 10, favourites: 20 + i, comments: 5 + i, downloads: i),
			publishedTime: "1700000000",
			allowsComments: true,
			isFavourited: false,
			isDeleted: false,
			thumbs: nil,
			content: nil
		)
	} : []
	let stacks = isAuthenticated ? (0..<stashCount).map { i in
		StashStack(
			stackid: "stash-\(i)",
			title: "Stash Stack \(i + 1)",
			items: [
				StashItem.preview(itemId: "item-\(i)-1", title: "Item 1"),
				StashItem.preview(itemId: "item-\(i)-2", title: "Item 2")
			]
		)
	} : []
	viewModel.configureForPreview(
		isAuthenticated: isAuthenticated,
		profile: profile,
		deviations: deviations,
		stashStacks: stacks,
		isLoading: isLoading,
		isRefreshing: isRefreshing,
		errorMessage: errorMessage
	)
	return viewModel
}

// MARK: - Patreon Preview Helper

@MainActor
public func previewPatreonViewModel(
	postCount: Int = 5,
	memberCount: Int = 3,
	isAuthenticated: Bool = true,
	isLoadingProfile: Bool = false,
	profileError: PatreonError? = nil,
	postsError: PatreonError? = nil
) -> PatreonViewModel {
	let settings = isAuthenticated
		? SettingsService.PatreonSettings(accessToken: "mock-token", campaignId: "campaign-123")
		: SettingsService.PatreonSettings(accessToken: "")

	let viewModel = PatreonViewModel(
		client: nil,
		settings: settings,
		dataStore: nil // Preview doesn't need database
	)
	viewModel.configureForPreview(
		isAuthenticated: isAuthenticated,
		posts: isAuthenticated ? (0..<postCount).map { i in
			PatreonPost(
				id: "post-\(i)",
				type: "post",
				attributes: PatreonPost.PatreonPostAttributes(
					title: "Post \(i + 1)",
					content: "<p>Content for post \(i + 1)</p>",
					url: "https://patreon.com/posts/post-\(i)",
					isPaid: i % 2 == 0,
					isPublic: i % 3 == 0,
					publishedAt: "2026-04-\(String(format: "%02d", (i % 30) + 1))T10:00:00.000Z"
				),
				relationships: nil
			)
		} : [],
		members: isAuthenticated ? (0..<memberCount).map { i in
			PatreonMember(
				id: "member-\(i)",
				type: "member",
				attributes: PatreonMember.PatreonMemberAttributes(
					fullName: "Patron \(i + 1)",
					email: "patron\(i)@example.com",
					patronStatus: i % 4 == 0 ? "declined_patron" : "active_patron",
					lastChargeStatus: i % 4 == 0 ? "Declined" : "Paid",
					lifetimeSupportCents: (i + 1) * 1000,
					currentlyEntitledAmountCents: (i + 1) * 100,
					isFollower: true,
					lastChargeDate: nil,
					pledgeRelationshipStart: nil,
					note: nil,
					campaignLifetimeSupportCents: (i + 1) * 1000,
					willPayAmountCents: (i + 1) * 100,
					nextChargeDate: nil,
					pledgeCadence: 1,
					isFreeTrial: false,
					isGifted: false
				),
				relationships: nil
			)
		} : [],
		isLoadingProfile: isLoadingProfile,
		profileError: profileError,
		postsError: postsError
	)
	return viewModel
}

// MARK: - Preview Data Extensions

extension PatreonMember {
	static var previewActive: PatreonMember {
		PatreonMember(
			id: "preview-member-active",
			type: "member",
			attributes: .init(
				fullName: "Alice Active",
				email: "alice@example.com",
				patronStatus: "active_patron",
				lastChargeStatus: "Paid",
				lifetimeSupportCents: 50000,
				currentlyEntitledAmountCents: 1000,
				isFollower: true,
				lastChargeDate: "2026-04-25T00:00:00.000Z",
				pledgeRelationshipStart: "2024-01-15T00:00:00.000Z",
				note: "Great supporter!",
				campaignLifetimeSupportCents: 50000,
				willPayAmountCents: 1000,
				nextChargeDate: "2026-05-25T00:00:00.000Z",
				pledgeCadence: 1,
				isFreeTrial: false,
				isGifted: false
			),
			relationships: nil
		)
	}

	static var previewDeclined: PatreonMember {
		PatreonMember(
			id: "preview-member-declined",
			type: "member",
			attributes: .init(
				fullName: "Bob Declined",
				email: "bob@example.com",
				patronStatus: "declined_patron",
				lastChargeStatus: "Declined",
				lifetimeSupportCents: 15000,
				currentlyEntitledAmountCents: 500,
				isFollower: true,
				lastChargeDate: "2026-04-01T00:00:00.000Z",
				pledgeRelationshipStart: "2025-01-01T00:00:00.000Z",
				note: nil,
				campaignLifetimeSupportCents: 15000,
				willPayAmountCents: nil,
				nextChargeDate: nil,
				pledgeCadence: 1,
				isFreeTrial: false,
				isGifted: false
			),
			relationships: nil
		)
	}

	static var previewFormer: PatreonMember {
		PatreonMember(
			id: "preview-member-former",
			type: "member",
			attributes: .init(
				fullName: "Charlie Former",
				email: "charlie@example.com",
				patronStatus: "former_patron",
				lastChargeStatus: nil,
				lifetimeSupportCents: 25000,
				currentlyEntitledAmountCents: nil,
				isFollower: false,
				lastChargeDate: "2025-12-01T00:00:00.000Z",
				pledgeRelationshipStart: "2024-06-01T00:00:00.000Z",
				note: nil,
				campaignLifetimeSupportCents: 25000,
				willPayAmountCents: nil,
				nextChargeDate: nil,
				pledgeCadence: 1,
				isFreeTrial: false,
				isGifted: false
			),
			relationships: nil
		)
	}

	static var previewNoEmail: PatreonMember {
		PatreonMember(
			id: "preview-member-noemail",
			type: "member",
			attributes: .init(
				fullName: "Dana NoEmail",
				email: nil,
				patronStatus: "active_patron",
				lastChargeStatus: "Paid",
				lifetimeSupportCents: 10000,
				currentlyEntitledAmountCents: 500,
				isFollower: true,
				lastChargeDate: "2026-04-20T00:00:00.000Z",
				pledgeRelationshipStart: "2025-03-01T00:00:00.000Z",
				note: nil,
				campaignLifetimeSupportCents: 10000,
				willPayAmountCents: 500,
				nextChargeDate: "2026-05-20T00:00:00.000Z",
				pledgeCadence: 1,
				isFreeTrial: false,
				isGifted: false
			),
			relationships: nil
		)
	}
}

extension PatreonPost {
	static var previewPaid: PatreonPost {
		PatreonPost(
			id: "preview-post-paid",
			type: "post",
			attributes: .init(
				title: "Premium Post Preview",
				content: "<p>This is a preview of a paid post with rich content.</p>",
				url: "https://patreon.com/posts/preview-paid",
				isPaid: true,
				isPublic: false,
				publishedAt: "2026-04-25T10:00:00.000Z"
			),
			relationships: nil
		)
	}

	static var previewPublic: PatreonPost {
		PatreonPost(
			id: "preview-post-public",
			type: "post",
			attributes: .init(
				title: "Public Post Preview",
				content: "<p>This is a preview of a public post.</p>",
				url: "https://patreon.com/posts/preview-public",
				isPaid: false,
				isPublic: true,
				publishedAt: "2026-04-24T10:00:00.000Z"
			),
			relationships: nil
		)
	}

	static var previewLongContent: PatreonPost {
		PatreonPost(
			id: "preview-post-long",
			type: "post",
			attributes: .init(
				title: "Very Long Post Title That Tests Layout and Truncation Behavior in the UI",
				content: """
				<p>This is a very long content section that contains multiple paragraphs.</p>
				<p>Second paragraph with <strong>bold text</strong> and <em>italic text</em>.</p>
				<p>Third paragraph with a <a href="https://example.com">link</a>.</p>
				<ul>
					<li>List item one</li>
					<li>List item two</li>
					<li>List item three with more text</li>
				</ul>
				""",
				url: "https://patreon.com/posts/long-post",
				isPaid: true,
				isPublic: false,
				publishedAt: "2026-04-20T08:00:00.000Z"
			),
			relationships: nil
		)
	}

	static var previewFree: PatreonPost {
		PatreonPost(
			id: "preview-post-free",
			type: "post",
			attributes: .init(
				title: "Free Patron Post",
				content: "<p>This post is free for all patrons.</p>",
				url: "https://patreon.com/posts/preview-free",
				isPaid: false,
				isPublic: false,
				publishedAt: "2026-04-23T10:00:00.000Z"
			),
			relationships: nil
		)
	}
}

extension StashItem {
	static func preview(itemId: String, title: String) -> StashItem {
		let json = """
		{
			"itemid": "\(itemId)",
			"stackid": "stack-1",
			"title": "\(title)",
			"path": "/path/to/file.png",
			"size": 1024000,
			"filesize": 1024000,
			"status": "draft",
			"thumb": null,
			"position": 1
		}
		"""
		return try! JSONDecoder().decode(StashItem.self, from: json.data(using: .utf8)!)
	}
}
#endif
