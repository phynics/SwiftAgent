//// JSONValue+OKJSONValue.swift
//
//import OllamaKit
//import JSONValue
//
//extension JSONValue {
//    public func toOKJSONValue() -> OKJSONValue {
//        switch self {
//        case .string(let value):
//            return .string(value)
//        case .float(let value):
//            return .number(value)
//        case .double(let value):
//            return .number(Float(value))
//        case .integer(let value):
//            return .integer(value)
//        case .boolean(let value):
//            return .boolean(value)
//        case .array(let value):
//            return .array(value.map { $0.toOKJSONValue() })
//        case .object(let value):
//            return .object(value.mapValues { $0.toOKJSONValue() })
//        }
//    }
//}
//
//extension OKJSONValue {
//    public func toJSONValue() -> JSONValue {
//        switch self {
//        case .string(let value):
//            return .string(value)
//        case .number(let value):
//            return .float(value)
//        case .integer(let value):
//            return .integer(value)
//        case .boolean(let value):
//            return .boolean(value)
//        case .array(let value):
//            return .array(value.map { $0.toJSONValue() })
//        case .object(let value):
//            return .object(value.mapValues { $0.toJSONValue() })
//        }
//    }
//}
