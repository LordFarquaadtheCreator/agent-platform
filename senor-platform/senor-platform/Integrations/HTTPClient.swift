import Foundation
import CryptoKit

/// Shared HTTP client infrastructure for API integrations
public final class HTTPClient {
    private let urlSession: URLSession
    private let configuration: Configuration
    private let logger = AppLogger.api

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.urlSession = URLSession(configuration: URLSessionConfiguration.default)
    }

    /// Configuration for HTTP client
    public struct Configuration: Sendable {
        public let baseURL: URL
        public let timeout: TimeInterval
        public let maxRetries: Int
        public let retryDelay: TimeInterval
        public let defaultHeaders: [String: String]

        public init(baseURL: URL, timeout: TimeInterval = 30, maxRetries: Int = 3, retryDelay: TimeInterval = 1.0, defaultHeaders: [String: String] = [:]) {
            self.baseURL = baseURL
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.retryDelay = retryDelay
            self.defaultHeaders = defaultHeaders
        }
    }

    /// Authentication token container
    public struct AuthToken: Sendable {
        public let accessToken: String
        public let refreshToken: String?
        public let expiresAt: Date?
        public let tokenType: String

        nonisolated public init(accessToken: String, refreshToken: String? = nil, expiresAt: Date? = nil, tokenType: String = "Bearer") {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.expiresAt = expiresAt
            self.tokenType = tokenType
        }

        nonisolated public var isExpired: Bool {
            guard let expiresAt = expiresAt else { return false }
            return Date() >= expiresAt
        }

        nonisolated public var authorizationHeader: String {
            "\(tokenType) \(accessToken)"
        }
    }

    /// HTTP request method
    public enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    /// API response wrapper
    public struct APIResponse<T> {
        public let data: T
        public let statusCode: Int
        public let headers: [String: String]
    }

    /// API error response
    public struct APIError: Error, Sendable {
        public let statusCode: Int
        public let message: String
        public let responseBody: Data?
        public let errorCode: String?

        public var isRateLimited: Bool { statusCode == 429 }
        public var isUnauthorized: Bool { statusCode == 401 }
        public var isNotFound: Bool { statusCode == 404 }
    }

    /// Perform authenticated request with automatic retry
    public func request<T: Decodable>(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil,
        authToken: AuthToken?,
        decodeAs type: T.Type
    ) async throws -> APIResponse<T> {
        let url = try buildURL(path: path, queryItems: queryItems)

        var attempts = 0
        var lastError: Error?

        for _ in 0..<configuration.maxRetries {
            do {
                let request = try buildRequest(
                    url: url,
                    method: method,
                    body: body,
                    authToken: authToken
                )

                logger.debug("Request: \(method.rawValue) \(url.absoluteString)")

                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.apiRequestFailed(path, NSError(domain: "HTTPClient", code: -1))
                }

                // Check for error status codes
                if (400...599).contains(httpResponse.statusCode) {
                    let error = parseError(data: data, statusCode: httpResponse.statusCode)

                    // Don't retry on 4xx client errors (except 429 rate limit)
                    if httpResponse.statusCode != 429 && (400...499).contains(httpResponse.statusCode) {
                        throw AppError.apiRequestFailed(path, error)
                    }

                    // Retry on 5xx or 429
                    lastError = error
                    attempts += 1
                    if attempts < 3 {
                        let delay = httpResponse.statusCode == 429 ? extractRetryAfter(from: httpResponse) : 1.0
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }

                // Parse success response
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                do {
                    let decodedData = try decoder.decode(T.self, from: data)

                    var headers: [String: String] = [:]
                    httpResponse.allHeaderFields.forEach { key, value in
                        if let key = key as? String, let value = value as? String {
                            headers[key] = value
                        }
                    }

                    logger.debug("Response: \(httpResponse.statusCode) for \(path)")

                    return APIResponse(data: decodedData, statusCode: httpResponse.statusCode, headers: headers)
                } catch {
                    logger.error("Failed to decode response: \(error)")
                    throw AppError.decodingFailed("Failed to decode response: \(error.localizedDescription)")
                }
            } catch {
                lastError = error
                attempts += 1
                if attempts < 3 {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }

        throw lastError ?? AppError.apiRequestFailed(path, NSError(domain: "HTTPClient", code: -1))
    }

    /// Perform request without authentication
    public func request<T: Decodable>(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil,
        decodeAs type: T.Type
    ) async throws -> APIResponse<T> {
        try await request(method: method, path: path, queryItems: queryItems, body: body, authToken: nil, decodeAs: type)
    }

    /// Build URL with path and query items
    private func buildURL(path: String, queryItems: [URLQueryItem]?) throws -> URL {
        // This is a placeholder - actual implementation needs base URL from config
        // For now, assume full path is provided
        guard let url = URL(string: path) else {
            throw AppError.invalidConfiguration("Invalid URL path: \(path)")
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw AppError.invalidConfiguration("Could not parse URL components: \(path)")
        }

        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let finalURL = components.url else {
            throw AppError.invalidConfiguration("Could not build final URL")
        }

        return finalURL
    }

    /// Build URLRequest with headers and body
    private func buildRequest(
        url: URL,
        method: HTTPMethod,
        body: Encodable?,
        authToken: AuthToken?
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SenorPlatform/1.0", forHTTPHeaderField: "User-Agent")

        if let authToken = authToken {
            request.setValue(authToken.authorizationHeader, forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    /// Build URLRequest with raw Data body (for JSON:API requests)
    private func buildRequest(
        url: URL,
        method: HTTPMethod,
        bodyData: Data?,
        contentType: String,
        authToken: AuthToken?
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SenorPlatform/1.0", forHTTPHeaderField: "User-Agent")

        if let authToken = authToken {
            request.setValue(authToken.authorizationHeader, forHTTPHeaderField: "Authorization")
        }

        if let bodyData = bodyData {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }

        return request
    }

    /// Perform request with raw Data body (for JSON:API requests)
    public func request<T: Decodable>(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        bodyData: Data?,
        contentType: String = "application/vnd.api+json",
        authToken: AuthToken?,
        decodeAs type: T.Type
    ) async throws -> APIResponse<T> {
        let url = try buildURL(path: path, queryItems: queryItems)

        let request = buildRequest(
            url: url,
            method: method,
            bodyData: bodyData,
            contentType: contentType,
            authToken: authToken
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.apiRequestFailed(path, NSError(domain: "HTTPClient", code: -1))
        }

        // Check for error status codes
        if (400...599).contains(httpResponse.statusCode) {
            throw AppError.apiRequestFailed(path, parseError(data: data, statusCode: httpResponse.statusCode))
        }

        // Parse success response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decodedData = try decoder.decode(T.self, from: data)

        var headers: [String: String] = [:]
        httpResponse.allHeaderFields.forEach { key, value in
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }

        return APIResponse(data: decodedData, statusCode: httpResponse.statusCode, headers: headers)
    }

    /// Parse error response
    private func parseError(data: Data, statusCode: Int) -> APIError {
        // Try to parse error details from response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let message = json["error_description"] as? String
                ?? json["message"] as? String
                ?? json["error"] as? String
                ?? "Request failed with status \(statusCode)"
            let errorCode = json["error"] as? String ?? json["code"] as? String
            return APIError(statusCode: statusCode, message: message, responseBody: data, errorCode: errorCode)
        }

        return APIError(
            statusCode: statusCode,
            message: "Request failed with status \(statusCode)",
            responseBody: data,
            errorCode: nil
        )
    }

    /// Extract retry-after header value
    private func extractRetryAfter(from response: HTTPURLResponse) -> TimeInterval {
        if let retryAfter = response.allHeaderFields["Retry-After"] as? String,
           let seconds = Double(retryAfter) {
            return seconds
        }
        return 60.0 // Default 1 minute
    }
}

// MARK: - Pagination Support

public protocol PaginatedResponse: Sendable {
    var hasMore: Bool { get }
    var nextCursor: String? { get }
    var items: [Sendable] { get }
}

/// Iterator for paginated API results
public final class PaginatedIterator<T: Decodable> {
    private let fetchPage: (String?) async throws -> HTTPClient.APIResponse<PaginatedPage<T>>
    private var currentCursor: String?
    private var hasMorePages: Bool = true
    private var buffer: [T] = []
    private var bufferIndex: Int = 0

    public struct PaginatedPage<U: Decodable>: Decodable {
        public let items: [U]
        public let nextCursor: String?
        public let hasMore: Bool
    }

    public init(fetchPage: @escaping (String?) async throws -> HTTPClient.APIResponse<PaginatedPage<T>>) {
        self.fetchPage = fetchPage
    }

    /// Get next item, fetching new pages as needed
    public func next() async throws -> T? {
        // Return from buffer if available
        if bufferIndex < buffer.count {
            let item = buffer[bufferIndex]
            bufferIndex += 1
            return item
        }

        // Fetch next page if available
        guard hasMorePages else {
            return nil
        }

        let response = try await fetchPage(currentCursor)
        buffer = response.data.items
        bufferIndex = 0
        currentCursor = response.data.nextCursor
        hasMorePages = response.data.hasMore && response.data.nextCursor != nil

        // Return first item from new page
        if bufferIndex < buffer.count {
            let item = buffer[bufferIndex]
            bufferIndex += 1
            return item
        }

        return nil
    }

    /// Collect all items (use with caution for large datasets)
    public func collectAll() async throws -> [T] {
        var allItems: [T] = []
        while let item = try await next() {
            allItems.append(item)
        }
        return allItems
    }
}

// MARK: - OAuth Support

/// OAuth flow helper with PKCE support
public actor OAuthHelper {
    private let clientId: String
    private let clientSecret: String
    private let redirectURI: String
    private let authURL: URL
    private let tokenURL: URL
    private let httpClient: HTTPClient

    /// Stored PKCE verifier for token exchange (protected by actor isolation)
    private var currentCodeVerifier: String?

    public struct TokenResponse: Decodable, Sendable {
        public let accessToken: String
        public let refreshToken: String?
        public let expiresIn: Int?
        public let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
        }
    }

    public init(
        clientId: String,
        clientSecret: String,
        redirectURI: String,
        authURL: URL,
        tokenURL: URL,
        httpClient: HTTPClient
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.authURL = authURL
        self.tokenURL = tokenURL
        self.httpClient = httpClient
    }

    /// Generate PKCE code verifier (random string 43-128 chars)
    private func generateCodeVerifier() -> String {
        let uuid1 = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let uuid2 = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return String((uuid1 + uuid2).prefix(128))
    }

    /// Generate PKCE code challenge from verifier (S256 method)
    private func generateCodeChallenge(verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        // SHA256 hash using CryptoKit
        let hash = SHA256.hash(data: data)
        // Convert to Data for base64 encoding
        let hashData = Data(hash)
        // Base64URL encode (no padding, no +/)
        return hashData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Generate authorization URL with PKCE
    /// - Returns: URL and the code verifier (must be stored and passed to exchangeCodeForToken)
    public func authorizationURLWithPKCE(scopes: [String], state: String) throws -> (url: URL, codeVerifier: String) {
        guard var components = URLComponents(url: authURL, resolvingAgainstBaseURL: true) else {
            throw AppError.invalidConfiguration("Invalid authorization URL")
        }

        // Generate and store PKCE verifier
        let codeVerifier = generateCodeVerifier()
        self.currentCodeVerifier = codeVerifier
        let codeChallenge = generateCodeChallenge(verifier: codeVerifier)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        if !scopes.isEmpty {
            queryItems.append(URLQueryItem(name: "scope", value: scopes.joined(separator: " ")))
        }

        components.queryItems = queryItems
        guard let url = components.url else {
            throw AppError.invalidConfiguration("Failed to construct authorization URL")
        }
        return (url, codeVerifier)
    }

    /// Legacy authorization URL without PKCE (not recommended)
    public func authorizationURL(scopes: [String], state: String) throws -> URL {
        let result = try authorizationURLWithPKCE(scopes: scopes, state: state)
        return result.url
    }

    /// Exchange authorization code for access token (with PKCE)
    public func exchangeCodeForToken(code: String, codeVerifier: String? = nil) async throws -> HTTPClient.AuthToken {
        var body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientId,
            "client_secret": clientSecret
        ]

        // Add PKCE code verifier if provided or stored
        let verifier = codeVerifier ?? currentCodeVerifier
        if let verifier = verifier {
            body["code_verifier"] = verifier
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncodedData(from: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OAuthTokenPayload.self, from: data)

        return makeAuthToken(from: response)
    }

    /// Refresh access token
    public func refreshToken(refreshToken: String) async throws -> HTTPClient.AuthToken {
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret
        ]

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncodedData(from: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OAuthTokenPayload.self, from: data)

        return makeAuthToken(from: response, fallbackRefreshToken: refreshToken)
    }
}

nonisolated private struct OAuthTokenPayload: Decodable, Sendable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int?
    let token_type: String
}

nonisolated private func formURLEncodedData(from parameters: [String: String]) -> Data? {
    var components = URLComponents()
    components.queryItems = parameters
        .sorted { $0.key < $1.key }
        .map { URLQueryItem(name: $0.key, value: $0.value) }
    return components.percentEncodedQuery?.data(using: .utf8)
}

nonisolated private func makeAuthToken(
    from payload: OAuthTokenPayload,
    fallbackRefreshToken: String? = nil
) -> HTTPClient.AuthToken {
    let expiresAt = payload.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) }
    return HTTPClient.AuthToken(
        accessToken: payload.access_token,
        refreshToken: payload.refresh_token ?? fallbackRefreshToken,
        expiresAt: expiresAt,
        tokenType: payload.token_type
    )
}
