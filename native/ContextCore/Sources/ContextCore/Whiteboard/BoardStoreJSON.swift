//  A JSON value the board store's cache keeps on disk as it came over the wire (plan
//  2026-11-24-boards-in-the-cockpit-plan.md section 7a, stories 1330-1334): bodies and ops are the Cockpit's and the
//  encoder's, so the cache carries every field through, known or not.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum BoardStoreJSON: Equatable, Hashable, Sendable {
  case null
  case bool(Bool)
  case int(Int64)
  case number(Double)
  case string(String)
  case array([BoardStoreJSON])
  case object([String: BoardStoreJSON])

  public var string: String? { if case .string(let value) = self { value } else { nil } }
  public var array: [BoardStoreJSON]? { if case .array(let value) = self { value } else { nil } }
  public var object: [String: BoardStoreJSON]? { if case .object(let value) = self { value } else { nil } }
  public var bool: Bool? { if case .bool(let value) = self { value } else { nil } }
  public var isNull: Bool { self == .null }

  public var int: Int? {
    switch self {
    case .int(let value): Int(exactly: value)
    case .number(let value): Int(exactly: value)
    default: nil
    }
  }

  /// The ids an array of strings names; nothing for anything else.
  public var strings: [String] { array?.compactMap(\.string) ?? [] }

  public subscript(key: String) -> BoardStoreJSON? {
    get { object?[key] }
    set {
      guard var object else { return }
      object[key] = newValue
      self = .object(object)
    }
  }

  /// As `JSONSerialization` gives it: what `BoardStoreClash.Op(json:)` reads.
  public var any: Any {
    switch self {
    case .null: Optional<Int>.none as Any
    case .bool(let value): value
    case .int(let value): value
    case .number(let value): value
    case .string(let value): value
    case .array(let value): value.map(\.any)
    case .object(let value): value.mapValues(\.any)
    }
  }
}

extension BoardStoreJSON: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int64.self) {
      self = .int(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([BoardStoreJSON].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: BoardStoreJSON].self))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let value): try container.encode(value)
    case .int(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }
}

extension BoardStoreJSON: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
  ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByFloatLiteral
{
  public init(stringLiteral value: String) { self = .string(value) }
  public init(integerLiteral value: Int64) { self = .int(value) }
  public init(floatLiteral value: Double) { self = .number(value) }
  public init(booleanLiteral value: Bool) { self = .bool(value) }
  public init(arrayLiteral elements: BoardStoreJSON...) { self = .array(elements) }
  public init(dictionaryLiteral elements: (String, BoardStoreJSON)...) {
    self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
  }
}
