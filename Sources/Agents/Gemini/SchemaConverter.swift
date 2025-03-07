import Foundation
import SwiftAgent
import JSONSchema
import GoogleGenerativeAI

/// Utility for converting between JSONSchema and GoogleGenerativeAI.Schema
public struct SchemaConverter {
    
    /// Converts a JSONSchema to GoogleGenerativeAI.Schema
    /// - Parameter jsonSchema: The source JSONSchema to convert
    /// - Returns: The converted GoogleGenerativeAI.Schema
    public static func convert(_ jsonSchema: JSONSchema) throws -> Schema {
        // Convert JSONSchema to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(jsonSchema)
        
        // Convert JSON to Dictionary
        guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw SchemaConversionError.invalidJsonData
        }
        
        // Get type
        let typeString = jsonObject["type"] as? String ?? "object"
        
        // Handle special case for properties that have enum values
        if let enumValues = getEnumValues(from: jsonObject) {
            // If it has enum values, treat it as a string with enum format
            return Schema(
                type: .string,
                format: "enum",
                description: jsonObject["description"] as? String,
                enumValues: enumValues
            )
        }
        
        // For regular types, continue with normal processing
        let dataType = mapJSONSchemaTypeToDataType(typeString)
        let description = jsonObject["description"] as? String
        
        // Build the schema based on type
        switch dataType {
        case .string:
            // For string type, check for special format or pattern
            let format = jsonObject["format"] as? String
            return Schema(
                type: dataType,
                format: format,
                description: description
            )
            
        case .number, .integer:
            return Schema(
                type: dataType,
                description: description
            )
            
        case .boolean:
            return Schema(
                type: dataType,
                description: description
            )
            
        case .array:
            var itemsSchema: Schema? = nil
            if let itemsObject = jsonObject["items"] as? [String: Any] {
                let itemsJsonData = try JSONSerialization.data(withJSONObject: itemsObject)
                let itemsJsonSchema = try JSONDecoder().decode(JSONSchema.self, from: itemsJsonData)
                itemsSchema = try convert(itemsJsonSchema)
            }
            
            // Create array schema with items
            if let itemsSchema = itemsSchema {
                // For arrays, we need to manually create the schema with items
                return Schema(
                    type: dataType,
                    description: description,
                    items: itemsSchema
                )
            } else {
                return Schema(
                    type: dataType,
                    description: description
                )
            }
            
        case .object:
            // For objects, we need to build manually with extracted properties
            let (properties, requiredProperties) = try extractObjectProperties(from: jsonObject)
            
            if let properties = properties {
                // Create a schema with properties and required fields
                return Schema(
                    type: dataType,
                    description: description,
                    properties: properties,
                    requiredProperties: requiredProperties
                )
            } else {
                // Create a simple object schema without properties
                return Schema(
                    type: dataType,
                    description: description
                )
            }
        }
    }
    
    /// Maps JSONSchema type string to GoogleGenerativeAI DataType
    /// - Parameter typeString: The type string from JSONSchema
    /// - Returns: The corresponding DataType
    private static func mapJSONSchemaTypeToDataType(_ typeString: String) -> DataType {
        switch typeString {
        case "string":
            return .string
        case "number":
            return .number
        case "integer":
            return .integer
        case "boolean":
            return .boolean
        case "array":
            return .array
        case "object", "enum":
            return .object
        default:
            return .object
        }
    }
    
    /// Gets enum values from the JSON object
    /// - Parameter jsonObject: The JSON object
    /// - Returns: Array of enum values if available
    private static func getEnumValues(from jsonObject: [String: Any]) -> [String]? {
        // Check for direct enum property
        if let enumValues = jsonObject["enum"] as? [Any] {
            return enumValues.compactMap { value in
                if let string = value as? String {
                    return string
                }
                return "\(value)" // Convert non-string values to string representation
            }
        }
        
        // Try to extract from enumSchema if present
        if let enumSchema = jsonObject["enumSchema"] as? [String: Any],
           let values = enumSchema["values"] as? [[String: Any]] {
            return values.compactMap { value in
                if let stringValue = value["string"] as? String {
                    return stringValue
                }
                return nil
            }
        }
        
        return nil
    }
    
    /// Extracts properties and required properties from an object schema
    /// - Parameter jsonObject: The JSON object
    /// - Returns: A tuple of properties dictionary and required properties array
    private static func extractObjectProperties(from jsonObject: [String: Any]) throws -> ([String: Schema]?, [String]?) {
        var schemaProperties: [String: Schema]? = nil
        var required: [String]? = nil
        
        // 直接プロパティを取得
        if let properties = jsonObject["properties"] as? [String: [String: Any]] {
            schemaProperties = [:]
            
            for (propertyName, propertyValue) in properties {
                let propertyData = try JSONSerialization.data(withJSONObject: propertyValue)
                let propertyJsonSchema = try JSONDecoder().decode(JSONSchema.self, from: propertyData)
                let convertedSchema = try convert(propertyJsonSchema)
                schemaProperties?[propertyName] = convertedSchema
            }
        }
        
        // 必須フィールドを取得
        if let requiredProps = jsonObject["required"] as? [String] {
            required = requiredProps
        }
        
        return (schemaProperties, required)
    }
}

/// Utility for converting SwiftAgent.Tool to GoogleGenerativeAI.FunctionDeclaration
public struct FunctionDeclarationConverter {
    
    /// Creates a FunctionDeclaration from a Tool
    /// - Parameter tool: The source Tool
    /// - Returns: The generated FunctionDeclaration
    public static func convert(from tool: any SwiftAgent.Tool) throws -> FunctionDeclaration {
        // Convert the JSONSchema to a dictionary representation
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(tool.parameters)
        guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw SchemaConversionError.invalidJsonData
        }
        
        // Extract properties from the schema
        var properties: [String: Schema]? = nil
        var requiredProperties: [String]? = nil
        
        // プロパティを直接取得
        if let props = jsonObject["properties"] as? [String: [String: Any]] {
            properties = [:]
            for (propName, propValue) in props {
                // Convert each property to a Schema
                let propData = try JSONSerialization.data(withJSONObject: propValue)
                let propSchema = try JSONDecoder().decode(JSONSchema.self, from: propData)
                properties?[propName] = try SchemaConverter.convert(propSchema)
            }
        }
        
        // 必須フィールドを直接取得
        if let required = jsonObject["required"] as? [String] {
            requiredProperties = required
        }
        
        return FunctionDeclaration(
            name: tool.name,
            description: tool.description,
            parameters: properties,
            requiredParameters: requiredProperties
        )
    }
}

/// Errors that can occur during schema conversion
public enum SchemaConversionError: Error {
    case invalidJsonData
    case missingType
    case unsupportedType(String)
    case propertyConversionError(String)
}
