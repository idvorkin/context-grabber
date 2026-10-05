//  JSON written the way JavaScript's JSON.stringify writes it, so the native export equals the React Native app's
//  byte for byte (spec step 4): keys in insertion order, numbers in JavaScript's shortest form (181, not 181.0),
//  only the escapes JavaScript makes ("/" and non-ASCII stay as they are), and the two-space indent of
//  JSON.stringify(x, null, 2). An absent optional field is left out, as JavaScript leaves out `undefined`.

import Foundation

public indirect enum JSValue: Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSValue])
  /// Keys in the order JavaScript would write them (insertion order; no key here is integer-like).
  case object([(String, JSValue)])

  public static func == (a: JSValue, b: JSValue) -> Bool {
    switch (a, b) {
    case (.null, .null): return true
    case (.bool(let x), .bool(let y)): return x == y
    case (.number(let x), .number(let y)): return x == y
    case (.string(let x), .string(let y)): return x == y
    case (.array(let x), .array(let y)): return x == y
    case (.object(let x), .object(let y)):
      return x.count == y.count && zip(x, y).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
    default: return false
    }
  }

  /// JSON.stringify(value) with no indent, or JSON.stringify(value, null, indent).
  public func stringify(indent: Int = 0) -> String {
    var out = ""
    write(into: &out, indent: indent, depth: 0)
    return out
  }

  private func write(into out: inout String, indent: Int, depth: Int) {
    switch self {
    case .null: out += "null"
    case .bool(let b): out += b ? "true" : "false"
    case .number(let n): out += JSValue.formatNumber(n)
    case .string(let s): JSValue.writeString(s, into: &out)
    case .array(let items):
      if items.isEmpty { out += "[]"; return }
      out += "["
      for (i, item) in items.enumerated() {
        if i > 0 { out += "," }
        if indent > 0 { out += "\n" + String(repeating: " ", count: indent * (depth + 1)) }
        item.write(into: &out, indent: indent, depth: depth + 1)
      }
      if indent > 0 { out += "\n" + String(repeating: " ", count: indent * depth) }
      out += "]"
    case .object(let fields):
      if fields.isEmpty { out += "{}"; return }
      out += "{"
      for (i, (key, value)) in fields.enumerated() {
        if i > 0 { out += "," }
        if indent > 0 { out += "\n" + String(repeating: " ", count: indent * (depth + 1)) }
        JSValue.writeString(key, into: &out)
        out += indent > 0 ? ": " : ":"
        value.write(into: &out, indent: indent, depth: depth + 1)
      }
      if indent > 0 { out += "\n" + String(repeating: " ", count: indent * depth) }
      out += "}"
    }
  }

  /// Number::toString: integers without a point, everything else in the shortest form that reads back the same.
  /// NaN and infinities are `null`, as in JSON.stringify.
  public static func formatNumber(_ n: Double) -> String {
    guard n.isFinite else { return "null" }
    if n == 0 { return "0" }  // -0 too
    if n == n.rounded(), abs(n) < 1e21 { return String(Int64(n)) }
    // Swift's description is the shortest round-trip digits too; only the exponent spelling differs
    // ("1e-07" → "1e-7", "1e+21" stays).
    var s = "\(n)"
    if let e = s.firstIndex(where: { $0 == "e" || $0 == "E" }) {
      var mantissa = String(s[..<e])
      var exponent = String(s[s.index(after: e)...])
      if mantissa.hasSuffix(".0") { mantissa.removeLast(2) }
      let negative = exponent.hasPrefix("-")
      exponent = exponent.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
      while exponent.count > 1 && exponent.hasPrefix("0") { exponent.removeFirst() }
      let value = Int(exponent) ?? 0
      // JavaScript writes plain decimals down to 1e-6 and up to 1e21.
      if negative && value <= 6 || !negative && value < 21 {
        return plainDecimal(n)
      }
      s = mantissa + "e" + (negative ? "-" : "+") + exponent
    }
    return s
  }

  private static func plainDecimal(_ n: Double) -> String {
    // Rare (|n| < 1e-4 in Swift's spelling): spell the shortest digits out without an exponent.
    let digits = "\(abs(n))"
    guard let e = digits.firstIndex(of: "e") else { return "\(n)" }
    let mantissa = digits[..<e].replacingOccurrences(of: ".", with: "")
    let exp = Int(digits[digits.index(after: e)...]) ?? 0
    let pointAt = (digits[..<e].firstIndex(of: ".").map { digits.distance(from: digits.startIndex, to: $0) } ?? mantissa.count) + exp
    var body: String
    if pointAt <= 0 {
      body = "0." + String(repeating: "0", count: -pointAt) + mantissa
    } else if pointAt >= mantissa.count {
      body = mantissa + String(repeating: "0", count: pointAt - mantissa.count)
    } else {
      let i = mantissa.index(mantissa.startIndex, offsetBy: pointAt)
      body = mantissa[..<i] + "." + mantissa[i...]
    }
    while body.contains(".") && (body.hasSuffix("0") || body.hasSuffix(".")) { body.removeLast() }
    return (n < 0 ? "-" : "") + body
  }

  private static func writeString(_ s: String, into out: inout String) {
    out += "\""
    for unit in s.unicodeScalars {
      switch unit {
      case "\"": out += "\\\""
      case "\\": out += "\\\\"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      case "\u{08}": out += "\\b"
      case "\u{0C}": out += "\\f"
      default:
        if unit.value < 0x20 {
          out += String(format: "\\u%04x", unit.value)
        } else {
          out.unicodeScalars.append(unit)
        }
      }
    }
    out += "\""
  }
}

// MARK: - building values

extension JSValue {
  public static func num(_ n: Double?) -> JSValue { n.map { .number($0) } ?? .null }
  public static func int(_ n: Int?) -> JSValue { n.map { .number(Double($0)) } ?? .null }
  public static func str(_ s: String?) -> JSValue { s.map { .string($0) } ?? .null }
}

// MARK: - reading (the cache)

extension JSValue {
  /// Parses JSON text (what the cache stored). Object key order follows the text.
  public static func parse(_ text: String) -> JSValue? {
    var parser = JSONTextParser(Array(text.utf8))
    guard let value = parser.value() else { return nil }
    parser.skipSpace()
    return parser.atEnd ? value : nil
  }

  public subscript(key: String) -> JSValue? {
    if case .object(let fields) = self { return fields.first { $0.0 == key }?.1 }
    return nil
  }

  public var double: Double? { if case .number(let n) = self { return n } else { return nil } }
  public var string: String? { if case .string(let s) = self { return s } else { return nil } }
  public var array: [JSValue]? { if case .array(let a) = self { return a } else { return nil } }
  public var isNull: Bool { self == .null }
}

/// A small strict JSON reader that keeps object key order (JSONSerialization does not).
private struct JSONTextParser {
  let bytes: [UInt8]
  var i = 0
  init(_ bytes: [UInt8]) { self.bytes = bytes }
  var atEnd: Bool { i >= bytes.count }

  mutating func skipSpace() {
    while i < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[i]) { i += 1 }
  }

  mutating func value() -> JSValue? {
    skipSpace()
    guard i < bytes.count else { return nil }
    switch bytes[i] {
    case UInt8(ascii: "{"):
      i += 1
      var fields: [(String, JSValue)] = []
      skipSpace()
      if i < bytes.count, bytes[i] == UInt8(ascii: "}") { i += 1; return .object(fields) }
      while true {
        skipSpace()
        guard let key = string() else { return nil }
        skipSpace()
        guard i < bytes.count, bytes[i] == UInt8(ascii: ":") else { return nil }
        i += 1
        guard let v = value() else { return nil }
        fields.append((key, v))
        skipSpace()
        guard i < bytes.count else { return nil }
        if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
        if bytes[i] == UInt8(ascii: "}") { i += 1; return .object(fields) }
        return nil
      }
    case UInt8(ascii: "["):
      i += 1
      var items: [JSValue] = []
      skipSpace()
      if i < bytes.count, bytes[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
      while true {
        guard let v = value() else { return nil }
        items.append(v)
        skipSpace()
        guard i < bytes.count else { return nil }
        if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
        if bytes[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
        return nil
      }
    case UInt8(ascii: "\""):
      return string().map { .string($0) }
    case UInt8(ascii: "t"): return literal("true", .bool(true))
    case UInt8(ascii: "f"): return literal("false", .bool(false))
    case UInt8(ascii: "n"): return literal("null", .null)
    default:
      let start = i
      while i < bytes.count, "+-0123456789.eE".utf8.contains(bytes[i]) { i += 1 }
      guard let text = String(bytes: bytes[start..<i], encoding: .utf8), let n = Double(text) else { return nil }
      return .number(n)
    }
  }

  mutating func literal(_ word: String, _ v: JSValue) -> JSValue? {
    let w = Array(word.utf8)
    guard i + w.count <= bytes.count, Array(bytes[i..<i + w.count]) == w else { return nil }
    i += w.count
    return v
  }

  mutating func string() -> String? {
    guard i < bytes.count, bytes[i] == UInt8(ascii: "\"") else { return nil }
    i += 1
    var scalars = String.UnicodeScalarView()
    var raw: [UInt8] = []
    func flush() {
      if !raw.isEmpty { scalars.append(contentsOf: (String(bytes: raw, encoding: .utf8) ?? "").unicodeScalars) }
      raw.removeAll()
    }
    while i < bytes.count {
      let b = bytes[i]
      if b == UInt8(ascii: "\"") { i += 1; flush(); return String(scalars) }
      if b == UInt8(ascii: "\\") {
        flush()
        i += 1
        guard i < bytes.count else { return nil }
        let e = bytes[i]
        i += 1
        switch e {
        case UInt8(ascii: "n"): scalars.append("\n")
        case UInt8(ascii: "r"): scalars.append("\r")
        case UInt8(ascii: "t"): scalars.append("\t")
        case UInt8(ascii: "b"): scalars.append("\u{08}")
        case UInt8(ascii: "f"): scalars.append("\u{0C}")
        case UInt8(ascii: "u"):
          guard let hi = hex4() else { return nil }
          if (0xD800..<0xDC00).contains(hi), i + 1 < bytes.count, bytes[i] == UInt8(ascii: "\\"),
            bytes[i + 1] == UInt8(ascii: "u")
          {
            i += 2
            guard let lo = hex4() else { return nil }
            let v = 0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00)
            if let s = Unicode.Scalar(v) { scalars.append(s) }
          } else if let s = Unicode.Scalar(hi) {
            scalars.append(s)
          }
        default: scalars.append(Unicode.Scalar(e))
        }
        continue
      }
      raw.append(b)
      i += 1
    }
    return nil
  }

  mutating func hex4() -> UInt32? {
    guard i + 4 <= bytes.count, let s = String(bytes: bytes[i..<i + 4], encoding: .ascii), let v = UInt32(s, radix: 16)
    else { return nil }
    i += 4
    return v
  }
}
