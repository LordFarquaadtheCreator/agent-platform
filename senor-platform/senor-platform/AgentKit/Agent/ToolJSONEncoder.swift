import Foundation

/// A helper that encodes arbitrary values to pretty-printed JSON strings.
/// If the value conforms to Encodable, it uses JSONEncoder.
/// Otherwise, it falls back to a Mirror-based best-effort encoding.
public struct JSONEncoderHelper {

    /// Encodes the given value to a pretty-printed JSON string.
    /// - Parameter value: The value to encode.
    /// - Returns: A pretty-printed JSON string if encoding succeeds, otherwise `nil`.
    public static func encodeToJSONString<T>(_ value: T) -> String? {
        if let encodableValue = value as? Encodable {
            return encodeEncodable(encodableValue)
        } else {
            return encodeWithMirror(value)
        }
    }

    /// Encodes an Encodable value to a pretty-printed JSON string.
    private static func encodeEncodable(_ value: Encodable) -> String? {
        // Use type erasure to encode Encodable protocol value
        struct AnyEncodable: Encodable {
            let wrapped: Encodable

            func encode(to encoder: Encoder) throws {
                try wrapped.encode(to: encoder)
            }
        }

        let anyEncodable = AnyEncodable(wrapped: value)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(anyEncodable)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Attempts a best-effort JSON encoding of the value using Mirror.
    private static func encodeWithMirror(_ value: Any) -> String? {
        let jsonObject = mirrorToJSONObject(value)
        guard JSONSerialization.isValidJSONObject(jsonObject) else { return nil }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Converts an arbitrary value to a JSON-compatible object using Mirror.
    private static func mirrorToJSONObject(_ value: Any) -> Any {
        func convert(_ any: Any) -> Any {
            let mirror = Mirror(reflecting: any)

            if mirror.displayStyle == .class || mirror.displayStyle == .struct {
                var dict = [String: Any]()
                for child in mirror.children {
                    if let label = child.label {
                        dict[label] = convert(child.value)
                    }
                }
                return dict
            } else if mirror.displayStyle == .optional {
                if let some = mirror.children.first {
                    return convert(some.value)
                } else {
                    return NSNull()
                }
            } else if mirror.displayStyle == .collection || mirror.displayStyle == .set {
                return mirror.children.map { convert($0.value) }
            } else if mirror.displayStyle == .dictionary {
                var dict = [String: Any]()
                for child in mirror.children {
                    let pairMirror = Mirror(reflecting: child.value)
                    if let keyChild = pairMirror.children.first,
                       let valueChild = pairMirror.children.dropFirst().first {
                        let key = "\(keyChild.value)"
                        dict[key] = convert(valueChild.value)
                    }
                }
                return dict
            } else if any is String || any is Int || any is Double || any is Bool || any is NSNull {
                return any
            } else {
                // Fallback to string representation
                return "\(any)"
            }
        }

        return convert(value)
    }

    /// Wraps a JSON string in a fenced code block for Markdown.
    /// - Parameter json: A JSON string.
    /// - Returns: The JSON string wrapped in a fenced code block with "json" language identifier.
    public static func jsonCodeBlock(_ json: String) -> String {
        "```json\n\(json)\n```"
    }
}
