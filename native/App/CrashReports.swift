//  Crash reports without a service (story 144). MetricKit hands the app its own crash and hang diagnostics on a
//  later launch; each payload is written under Documents/crashes/ and announced in the session log as
//  `crash_report`. MetricKit can take days on a development build, so the app also keeps its own last-resort
//  files in the same folder: `signal-<epoch>.txt` (the crashing thread's raw backtrace) or, for an Objective-C
//  exception, `exception-<epoch>.txt` with its name, reason and stack — one file per crash. `just pull-logs`
//  copies the folder.

import Darwin
import Foundation
import MetricKit

/// The folder's path for the signal handler, which may only make async-signal-safe calls.
private var crashFolderPath = [CChar](repeating: 0, count: 1024)

/// Set once the exception file is on disk: the abort that follows is the same crash and writes no second file.
private var exceptionFileWritten: sig_atomic_t = 0

private func writeAll(_ fd: Int32, _ text: String) {
  text.utf8CString.withUnsafeBufferPointer { buffer in
    _ = write(fd, buffer.baseAddress, buffer.count - 1)
  }
}

private func crashSignalHandler(_ signal: Int32) {
  if exceptionFileWritten == 0 { writeSignalFile(signal) }
  Darwin.signal(signal, SIG_DFL)
  raise(signal)
}

private func writeSignalFile(_ signal: Int32) {
  var path = crashFolderPath
  let name = "/signal-\(Int(time(nil))).txt"
  name.utf8CString.withUnsafeBufferPointer { src in
    let base = strlen(path)
    guard base + src.count < path.count else { return }
    for i in 0..<src.count { path[base + i] = src[i] }
  }
  let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
  guard fd >= 0 else { return }
  writeAll(fd, "signal \(signal)\n")
  var frames = [UnsafeMutableRawPointer?](repeating: nil, count: 128)
  let count = backtrace(&frames, Int32(frames.count))
  backtrace_symbols_fd(&frames, count, fd)
  close(fd)
}

final class CrashReports: NSObject, MXMetricManagerSubscriber {
  static let shared = CrashReports()
  var onEvent: ((String, [String: Any]) -> Void)?

  static var folder: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("crashes", isDirectory: true)
  }

  func install() {
    MXMetricManager.shared.add(self)
    try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
    Self.folder.path.utf8CString.withUnsafeBufferPointer { src in
      for i in 0..<min(src.count, crashFolderPath.count - 64) { crashFolderPath[i] = src[i] }
    }
    for sig in [SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGTRAP, SIGFPE] { signal(sig, crashSignalHandler) }
    // An Objective-C exception aborts through SIGABRT and the signal backtrace never says which one; this runs
    // first, on the throwing thread.
    NSSetUncaughtExceptionHandler { exception in
      let text =
        "exception \(exception.name.rawValue)\n\(exception.reason ?? "")\n"
        + exception.callStackSymbols.joined(separator: "\n") + "\n"
      let file = CrashReports.folder.appendingPathComponent("exception-\(Int(Date().timeIntervalSince1970)).txt")
      if (try? text.write(to: file, atomically: true, encoding: .utf8)) != nil { exceptionFileWritten = 1 }
    }
  }

  /// Signal and exception files from earlier runs, announced once and then renamed. A renamed file keeps its
  /// `.txt` suffix, so the `.reported.` marker is what excludes it.
  func reportSignalLogs(_ log: (String, [String: Any]) -> Void) {
    let files = (try? FileManager.default.contentsOfDirectory(atPath: Self.folder.path)) ?? []
    for name in files.sorted()
    where (name.hasPrefix("signal-") || name.hasPrefix("exception-")) && name.hasSuffix(".txt")
      && !name.contains(".reported.")
    {
      let url = Self.folder.appendingPathComponent(name)
      let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
      let top = text.split(separator: "\n").prefix(12).joined(separator: " | ")
      log(
        "crash_report",
        ["kind": name.hasPrefix("signal-") ? "signal" : "exception", "file": "crashes/\(name)", "top": top])
      try? FileManager.default.moveItem(
        at: url,
        to: Self.folder.appendingPathComponent(name.replacingOccurrences(of: ".txt", with: ".reported.txt")))
    }
  }

  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    for payload in payloads {
      let crashes = payload.crashDiagnostics ?? []
      let hangs = payload.hangDiagnostics ?? []
      guard !crashes.isEmpty || !hangs.isEmpty else { continue }
      let name = "\(formatter.string(from: payload.timeStampEnd)).json"
      try? payload.jsonRepresentation().write(to: Self.folder.appendingPathComponent(name))
      for crash in crashes {
        onEvent?(
          "crash_report",
          [
            "file": "crashes/\(name)", "kind": "crash",
            "exception": crash.exceptionType?.intValue ?? 0, "code": crash.exceptionCode?.intValue ?? 0,
            "signal": crash.signal?.intValue ?? 0, "reason": crash.terminationReason ?? "",
            "app": crash.applicationVersion, "ended": ISO8601DateFormatter().string(from: payload.timeStampEnd),
          ])
      }
      for hang in hangs {
        onEvent?("crash_report", ["file": "crashes/\(name)", "kind": "hang", "seconds": hang.hangDuration.value])
      }
    }
  }

  func didReceive(_ payloads: [MXMetricPayload]) {}
}
