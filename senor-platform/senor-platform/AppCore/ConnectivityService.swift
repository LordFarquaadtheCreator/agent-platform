import Foundation
import Network
import Combine

@MainActor
public final class ConnectivityService: ObservableObject {
	public let objectWillChange = ObservableObjectPublisher()
	public var isOnline = true {
		willSet { objectWillChange.send() }
	}
	public var isChecking = false {
		willSet { objectWillChange.send() }
	}

	private let monitor = NWPathMonitor()
	private let queue = DispatchQueue(label: "connectivity-monitor")
	private let logger = AppLogger.general

	public init() {
		monitor.pathUpdateHandler = { [weak self] path in
			let online = path.status == .satisfied
			Task { @MainActor in
				self?.isOnline = online
			}
			if !online {
				self?.logger.warning("Network offline")
			}
		}
		monitor.start(queue: queue)
	}

	deinit {
		monitor.cancel()
	}

	/// Ping a host to confirm actual reachability beyond local network
	public func checkReachability(to host: String) async -> Bool {
		isChecking = true
		defer { isChecking = false }

		guard let url = URL(string: host) else {
			isOnline = false
			return false
		}

		var request = URLRequest(url: url)
		request.httpMethod = "HEAD"
		request.timeoutInterval = 10

		do {
			let (_, response) = try await URLSession.shared.data(for: request)
			let reachable = (response as? HTTPURLResponse)?.statusCode != nil
			isOnline = reachable
			return reachable
		} catch {
			isOnline = false
			logger.warning("Reachability check failed for \(host): \(error.localizedDescription)")
			return false
		}
	}
}
