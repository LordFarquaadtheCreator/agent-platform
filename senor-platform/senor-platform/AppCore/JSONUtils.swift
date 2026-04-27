import Foundation

/// Utility functions for JSON operations
public enum JSONUtils {
    /// Format JSON string with pretty printing and sorted keys
    public static func format(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formattedData = try? JSONSerialization.data(
                withJSONObject: json,
                options: [.prettyPrinted, .sortedKeys]
            ) else {
            return nil
        }
        return String(data: formattedData, encoding: .utf8)
    }

    /// Validate JSON string syntax
    public static func validate(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// Parse JSON string to dictionary
    public static func parseToDictionary(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }

    /// Convert dictionary to JSON string
    public static func stringify(_ dict: [String: Any], pretty: Bool = false) -> String? {
        var options: JSONSerialization.WritingOptions = [.sortedKeys]
        if pretty {
            options.insert(.prettyPrinted)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: options) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Extract string value from JSON dictionary
    public static func extractString(from dict: [String: Any], key: String) -> String? {
        dict[key] as? String
    }

    /// Extract nested string value using key path
    public static func extractString(from dict: [String: Any], keyPath: String) -> String? {
        var current: Any? = dict
        for key in keyPath.split(separator: ".") {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[String(key)]
        }
        return current as? String
    }
}
