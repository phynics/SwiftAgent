import Testing
import Foundation
@testable import SwiftAgent

// Test用の構造体
struct BasicTypes: Codable, Sendable {
    let stringValue: String
    let intValue: Int
    let doubleValue: Double
    let boolValue: Bool
}

struct OptionalTypes: Codable, Sendable {
    let optionalString: String?
    let optionalInt: Int?
    let optionalDouble: Double?
    let optionalBool: Bool?
}

struct ArrayTypes: Codable, Sendable {
    let stringArray: [String]
    let intArray: [Int]
    let doubleArray: [Double]
    let boolArray: [Bool]
}

struct NestedType: Codable, Sendable {
    let basic: BasicTypes
    let optional: OptionalTypes
    let array: ArrayTypes
}

@Test("Basic type encoding")
func testBasicTypeEncoding() throws {

    
    func getCodingKeys<T: Codable>(for type: T.Type) -> [String] {
        guard let codingKeysType = type as? any CodingKey.Type else {
            print("CodingKeys not found for \(type)")
            return []
        }
        
        // リフレクションを使って列挙子を取得
        let mirror = Mirror(reflecting: codingKeysType)
        return mirror.children.compactMap { $0.value as? String }
    }
    
    // 使用例
    let properties = getCodingKeys(for: BasicTypes.self)
    print("Properties: \(properties)")
    
}
//
//@Test("Optional type encoding")
//func testOptionalTypeEncoding() throws {
//    let encoder = JSONSchemaEncoder()
//    let schema = encoder.encode(OptionalTypes.self)
//    
//    guard let properties = schema["properties"] as? [String: [String: Any]] else {
//        #expect(false, "Properties should be a dictionary")
//        return
//    }
//    
//    // Optional String型のテスト
//    guard let optionalString = properties["optionalString"]?["anyOf"] as? [[String: Any]] else {
//        #expect(false, "Optional string should have anyOf")
//        return
//    }
//    #expect(optionalString[0]["type"] as? String == "string")
//    #expect(optionalString[1]["type"] as? String == "null")
//    
//    // 必須フィールドがないことのテスト
//    guard let required = schema["required"] as? [String] else {
//        #expect(false, "Required should be an array")
//        return
//    }
//    #expect(required.isEmpty)
//}
//
//@Test("Array type encoding")
//func testArrayTypeEncoding() throws {
//    let encoder = JSONSchemaEncoder()
//    let schema = encoder.encode(ArrayTypes.self)
//    
//    guard let properties = schema["properties"] as? [String: [String: Any]] else {
//        #expect(false, "Properties should be a dictionary")
//        return
//    }
//    
//    // String配列のテスト
//    guard let stringArray = properties["stringArray"] else {
//        #expect(false, "String array should exist")
//        return
//    }
//    #expect(stringArray["type"] as? String == "array")
//    #expect((stringArray["items"] as? [String: Any])?["type"] as? String == "string")
//    
//    // Int配列のテスト
//    guard let intArray = properties["intArray"] else {
//        #expect(false, "Int array should exist")
//        return
//    }
//    #expect(intArray["type"] as? String == "array")
//    #expect((intArray["items"] as? [String: Any])?["type"] as? String == "integer")
//    
//    // 必須フィールドのテスト
//    guard let required = schema["required"] as? [String] else {
//        #expect(false, "Required should be an array")
//        return
//    }
//    #expect(required.contains("stringArray"))
//    #expect(required.contains("intArray"))
//}
//
//@Test("Nested type encoding")
//func testNestedTypeEncoding() throws {
//    let encoder = JSONSchemaEncoder()
//    let schema = encoder.encode(NestedType.self)
//    
//    guard let properties = schema["properties"] as? [String: [String: Any]] else {
//        #expect(false, "Properties should be a dictionary")
//        return
//    }
//    
//    // ネストされた基本型のテスト
//    guard let basic = properties["basic"] else {
//        #expect(false, "Basic nested type should exist")
//        return
//    }
//    #expect(basic["type"] as? String == "object")
//    
//    // ネストされたOptional型のテスト
//    guard let optional = properties["optional"] else {
//        #expect(false, "Optional nested type should exist")
//        return
//    }
//    #expect(optional["type"] as? String == "object")
//    
//    // ネストされた配列型のテスト
//    guard let array = properties["array"] else {
//        #expect(false, "Array nested type should exist")
//        return
//    }
//    #expect(array["type"] as? String == "object")
//    
//    // 必須フィールドのテスト
//    guard let required = schema["required"] as? [String] else {
//        #expect(false, "Required should be an array")
//        return
//    }
//    #expect(required.contains("basic"))
//    #expect(required.contains("optional"))
//    #expect(required.contains("array"))
//}
