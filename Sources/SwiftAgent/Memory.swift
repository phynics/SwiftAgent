//
//  Memory.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//



import Foundation

/// A storage class for holding a value.
///
/// `ValueStorage` provides a simple way to encapsulate a value
/// and manage its updates.
final class ValueStorage<Value> {
    /// The stored value.
    var value: Value
    
    /// Initializes a new `ValueStorage` with a given value.
    ///
    /// - Parameter value: The initial value to store.
    init(value: Value) {
        self.value = value
    }
}

/// A property wrapper and dynamic member lookup structure for value relays.
///
/// `Relay` provides a mechanism to wrap a value and access it dynamically through
/// closures, allowing for flexible and reactive value management.
@propertyWrapper @dynamicMemberLookup
public struct Relay<Value> {
    // Internal getter and setter closures.
    private let getter: () -> Value
    private let setter: (Value) -> Void
    
    /// Initializes a new relay with getter and setter closures.
    ///
    /// - Parameters:
    ///   - get: A closure that retrieves the current value.
    ///   - set: A closure that updates the value.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }
    
    /// Creates a constant, immutable relay.
    ///
    /// - Parameter value: The immutable value to be wrapped.
    /// - Returns: A `Relay` instance with a fixed value.
    public static func constant(_ value: Value) -> Relay<Value> {
        Relay(get: { value }, set: { _ in })
    }
    
    /// The current value referenced by the relay.
    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }
    
    /// A projection of the relay that can be passed to child steps or components.
    public var projectedValue: Relay<Value> { self }
    
    /// Initializes a new relay from another relay's projected value.
    ///
    /// - Parameter projectedValue: An existing relay to copy.
    public init(projectedValue: Relay<Value>) {
        self.getter = projectedValue.getter
        self.setter = projectedValue.setter
    }
    
    /// Returns a relay that references the value of a given key path.
    ///
    /// - Parameter keyPath: A key path to the property to access.
    /// - Returns: A `Relay` instance for the key path's value.
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Relay<Subject> {
        Relay<Subject>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Optional Support

extension Relay {
    /// Initializes a relay by projecting an optional base value.
    ///
    /// - Parameter base: A relay that wraps a non-optional value.
    public init<V>(_ base: Relay<V>) where Value == V? {
        self.getter = { Optional(base.wrappedValue) }
        self.setter = { newValue in
            if let value = newValue {
                base.wrappedValue = value
            }
        }
    }
    
    /// Initializes a relay by projecting an optional base value to an unwrapped value.
    ///
    /// - Parameter base: A relay that wraps an optional value.
    /// - Returns: A `Relay` instance if the base contains a non-nil value, otherwise `nil`.
    public init?(_ base: Relay<Value?>) {
        guard let value = base.wrappedValue else { return nil }
        self.getter = { base.wrappedValue ?? value }
        self.setter = { base.wrappedValue = $0 }
    }
}

/// A property wrapper that stores a value in memory.
///
/// `Memory` allows encapsulation of a value while providing
/// a `Relay` projection for reactive value management.
@propertyWrapper
public struct Memory<Value> {
    private let storage: ValueStorage<Value>
    
    /// Initializes a new `Memory` property wrapper with an initial value.
    ///
    /// - Parameter wrappedValue: The initial value to store.
    public init(wrappedValue value: Value) {
        self.storage = ValueStorage(value: value)
    }
    
    /// The stored value.
    public var wrappedValue: Value {
        get { storage.value }
        set { storage.value = newValue }
    }
    
    /// A `Relay` projection of the stored value, enabling dynamic access and updates.
    public var projectedValue: Relay<Value> {
        Relay(
            get: { self.storage.value },
            set: { self.storage.value = $0 }
        )
    }
}
