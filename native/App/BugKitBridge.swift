//  BugKit's events arrive as JSON values; the session log takes Foundation values. EA has the same 12 lines; if a
//  third app needs them they move into BugKit (EA's migration note).

import BugKit
import Foundation

extension JSONValue {
  var foundation: Any {
    switch self {
    case .null: return NSNull()
    case .bool(let b): return b
    case .int(let i): return i
    case .double(let d): return d
    case .string(let s): return s
    case .array(let a): return a.map(\.foundation)
    case .object(let o): return o.mapValues(\.foundation)
    }
  }
}
