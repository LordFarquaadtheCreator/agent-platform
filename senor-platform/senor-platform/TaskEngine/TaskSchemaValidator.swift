import Foundation

/// Validates task metadata against JSON Schema definitions
public final class TaskSchemaValidator: Sendable {
    private let logger = AppLogger.taskEngine

    public init() {}

    /// Validate task metadata against a JSON schema
    public func validate(metadata: [String: Any], schema: [String: Any]) -> Result<Void, AppError> {
        // Basic JSON schema validation implementation
        // In production, consider using a full JSON Schema library

        do {
            // Check required fields
            if let required = schema["required"] as? [String] {
                for field in required {
                    if metadata[field] == nil {
                        return .failure(.schemaValidationFailed(
                            "task",
                            [.init(field: field, message: "Required field is missing", jsonPointer: "/\(field)")]
                        ))
                    }
                }
            }

            // Check property types and constraints
            if let properties = schema["properties"] as? [String: [String: Any]] {
                for (propertyName, propertySchema) in properties {
                    if let value = metadata[propertyName] {
                        let errors = validateProperty(
                            name: propertyName,
                            value: value,
                            schema: propertySchema,
                            pointer: "/\(propertyName)"
                        )
                        if !errors.isEmpty {
                            return .failure(.schemaValidationFailed("task", errors))
                        }
                    }
                }
            }

            return .success(())
        } catch {
            return .failure(.invalidJSON("Validation failed: \(error.localizedDescription)"))
        }
    }

    /// Validate JSON string against schema string
    public func validate(metadataJson: String, schemaJson: String) -> Result<Void, AppError> {
        guard let metadata = try? JSONSerialization.jsonObject(with: metadataJson.data(using: .utf8)!) as? [String: Any] else {
            return .failure(.invalidJSON("Metadata is not valid JSON"))
        }

        guard let schema = try? JSONSerialization.jsonObject(with: schemaJson.data(using: .utf8)!) as? [String: Any] else {
            return .failure(.invalidJSON("Schema is not valid JSON"))
        }

        return validate(metadata: metadata, schema: schema)
    }

    /// Validate with detailed error list
    public func validateWithDetails(metadata: [String: Any], schema: [String: Any]) -> [AppError.ValidationError] {
        var errors: [AppError.ValidationError] = []

        // Check required fields
        if let required = schema["required"] as? [String] {
            for field in required {
                if metadata[field] == nil {
                    errors.append(.init(
                        field: field,
                        message: "Required field is missing",
                        jsonPointer: "/\(field)"
                    ))
                }
            }
        }

        // Check property types and constraints
        if let properties = schema["properties"] as? [String: [String: Any]] {
            for (propertyName, propertySchema) in properties {
                if let value = metadata[propertyName] {
                    let propErrors = validateProperty(
                        name: propertyName,
                        value: value,
                        schema: propertySchema,
                        pointer: "/\(propertyName)"
                    )
                    errors.append(contentsOf: propErrors)
                }
            }
        }

        return errors
    }

    // MARK: - Private Validation Methods

    private func validateProperty(
        name: String,
        value: Any,
        schema: [String: Any],
        pointer: String
    ) -> [AppError.ValidationError] {
        var errors: [AppError.ValidationError] = []

        // Check type
        if let expectedType = schema["type"] as? String {
            if !isValidType(value: value, expectedType: expectedType) {
                errors.append(.init(
                    field: name,
                    message: "Expected type '\(expectedType)' but got '\(type(of: value))'",
                    jsonPointer: pointer
                ))
            }
        }

        // Check string constraints
        if let stringValue = value as? String {
            if let minLength = schema["minLength"] as? Int, stringValue.count < minLength {
                errors.append(.init(
                    field: name,
                    message: "String must be at least \(minLength) characters",
                    jsonPointer: pointer
                ))
            }
            if let maxLength = schema["maxLength"] as? Int, stringValue.count > maxLength {
                errors.append(.init(
                    field: name,
                    message: "String must be at most \(maxLength) characters",
                    jsonPointer: pointer
                ))
            }
            if let pattern = schema["pattern"] as? String {
                let regex = try? NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(stringValue.startIndex..., in: stringValue)
                if regex?.firstMatch(in: stringValue, options: [], range: range) == nil {
                    errors.append(.init(
                        field: name,
                        message: "String does not match required pattern",
                        jsonPointer: pointer
                    ))
                }
            }
        }

        // Check numeric constraints
        if let numberValue = value as? NSNumber {
            let doubleValue = numberValue.doubleValue
            if let minimum = schema["minimum"] as? Double, doubleValue < minimum {
                errors.append(.init(
                    field: name,
                    message: "Value must be at least \(minimum)",
                    jsonPointer: pointer
                ))
            }
            if let maximum = schema["maximum"] as? Double, doubleValue > maximum {
                errors.append(.init(
                    field: name,
                    message: "Value must be at most \(maximum)",
                    jsonPointer: pointer
                ))
            }
        }

        // Check enum
        if let enumValues = schema["enum"] as? [Any] {
            let isValid = enumValues.contains { enumValue in
                String(describing: enumValue) == String(describing: value)
            }
            if !isValid {
                errors.append(.init(
                    field: name,
                    message: "Value must be one of: \(enumValues.map { String(describing: $0) }.joined(separator: ", "))",
                    jsonPointer: pointer
                ))
            }
        }

        // Check array constraints
        if let arrayValue = value as? [Any] {
            if let minItems = schema["minItems"] as? Int, arrayValue.count < minItems {
                errors.append(.init(
                    field: name,
                    message: "Array must have at least \(minItems) items",
                    jsonPointer: pointer
                ))
            }
            if let maxItems = schema["maxItems"] as? Int, arrayValue.count > maxItems {
                errors.append(.init(
                    field: name,
                    message: "Array must have at most \(maxItems) items",
                    jsonPointer: pointer
                ))
            }

            // Validate array items
            if let itemsSchema = schema["items"] as? [String: Any] {
                for (index, item) in arrayValue.enumerated() {
                    let itemErrors = validateProperty(
                        name: "\(name)[\(index)]",
                        value: item,
                        schema: itemsSchema,
                        pointer: "\(pointer)/\(index)"
                    )
                    errors.append(contentsOf: itemErrors)
                }
            }
        }

        // Check object properties recursively
        if let objectValue = value as? [String: Any],
           let properties = schema["properties"] as? [String: [String: Any]] {
            for (propName, propSchema) in properties {
                if let propValue = objectValue[propName] {
                    let nestedErrors = validateProperty(
                        name: "\(name).\(propName)",
                        value: propValue,
                        schema: propSchema,
                        pointer: "\(pointer)/\(propName)"
                    )
                    errors.append(contentsOf: nestedErrors)
                }
            }
        }

        return errors
    }

    private func isValidType(value: Any, expectedType: String) -> Bool {
        switch expectedType {
        case "string":
            return value is String
        case "integer":
            return value is Int
        case "number":
            return value is NSNumber || value is Double || value is Int
        case "boolean":
            return value is Bool
        case "array":
            return value is [Any]
        case "object":
            return value is [String: Any]
        case "null":
            return value is NSNull || (value as? String) == nil
        default:
            return true
        }
    }

    /// Create a basic JSON schema from a sample object structure
    public func inferSchema(from sample: [String: Any]) -> [String: Any] {
        var properties: [String: [String: Any]] = [:]
        var required: [String] = []

        for (key, value) in sample {
            let type = jsonType(for: value)
            properties[key] = ["type": type]
            required.append(key)
        }

        return [
            "type": "object",
            "properties": properties,
            "required": required
        ]
    }

    private func jsonType(for value: Any) -> String {
        switch value {
        case is String:
            return "string"
        case is Int:
            return "integer"
        case is Double, is Float:
            return "number"
        case is Bool:
            return "boolean"
        case is [Any]:
            return "array"
        case is [String: Any]:
            return "object"
        default:
            return "null"
        }
    }
}
