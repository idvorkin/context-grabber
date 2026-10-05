//  The voice bridge's socket, on URLSessionWebSocketTask. Every callback arrives on the main queue (the
//  session's delegate queue), which is where CallSession lives. A bridge that does not answer within ten seconds
//  is a failure, not a hang (call screen spec, acceptance 12).

import ContextCore
import Foundation

final class BridgeWebSocket: NSObject, BridgeSocket, URLSessionWebSocketDelegate {
  var onOpen: (() -> Void)?
  var onText: ((String) -> Void)?
  var onBinary: ((Data) -> Void)?
  var onClose: ((String) -> Void)?

  static let connectTimeout: TimeInterval = 10

  private var session: URLSession!
  private var task: URLSessionWebSocketTask!
  private var opened = false
  private var gone = false

  init(url: URL) {
    super.init()
    let config = URLSessionConfiguration.default
    config.waitsForConnectivity = false
    session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    task = session.webSocketTask(with: url)
    task.maximumMessageSize = 8 * 1024 * 1024
    task.resume()
    receive()
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectTimeout) { [weak self] in
      guard let self, !self.opened else { return }
      self.finish("no answer from \(url.host ?? "the bridge") in \(Int(Self.connectTimeout)) s")
    }
  }

  func send(text: String) {
    guard !gone else { return }
    task.send(.string(text)) { _ in }  // a failed send is followed by the receive loop's failure, which reports it
  }

  func send(data: Data) {
    guard !gone else { return }
    task.send(.data(data)) { _ in }
  }

  /// Ours: no `onClose` for a close we asked for.
  func close() {
    guard !gone else { return }
    gone = true
    task.cancel(with: .normalClosure, reason: nil)
    session.invalidateAndCancel()  // the session holds its delegate; this lets both go
  }

  private func receive() {
    task.receive { [weak self] result in
      DispatchQueue.main.async {
        guard let self, !self.gone else { return }
        switch result {
        case .success(.string(let text)):
          self.onText?(text)
          self.receive()
        case .success(.data(let data)):
          self.onBinary?(data)
          self.receive()
        case .success:
          self.receive()
        case .failure(let error):
          self.finish(describe(error))
        }
      }
    }
  }

  private func finish(_ why: String) {
    guard !gone else { return }
    gone = true
    task.cancel(with: .goingAway, reason: nil)
    session.invalidateAndCancel()
    onClose?(why)
  }

  // MARK: - URLSessionWebSocketDelegate (on the main queue)

  func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
    guard !gone else { return }
    opened = true
    onOpen?()
  }

  func urlSession(
    _ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
    reason: Data?
  ) {
    finish("closed by the bridge (code \(closeCode.rawValue))")
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    finish(error.map(describe) ?? "socket completed")
  }
}
