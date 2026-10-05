//  The call screen (stories 080–095): Call Larry, the calling ring, one compact call line with mute (the voice
//  level), restart and hang-up, the live line, the captions, and the Diagnostics fold. Closing it leaves a live
//  call running; the home screen's Call row brings it back.

import ContextCore
import SwiftUI
import UIKit

private let hangUpRed = Color(red: 0.902, green: 0.224, blue: 0.275)

struct CallView: View {
  @ObservedObject var call: CallModel
  let onDone: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var diagnosticsOpen = false
  @State private var copied = false
  @State private var expanded: Set<Int> = []

  var body: some View {
    VStack(spacing: 0) {
      callLine
      if call.snapshot.isActive || call.snapshot.state == .ended { Divider() }
      content
    }
    .onAppear { keepAwake() }
    .onDisappear { setAwake(false) }
    .onChange(of: call.snapshot.isActive) { _, _ in keepAwake() }
  }

  /// While this screen is in front during a call the screen stays lit; the call no longer depends on it.
  private func keepAwake() { setAwake(call.snapshot.isActive) }

  private func setAwake(_ on: Bool) {
    guard UIApplication.shared.isIdleTimerDisabled != on else { return }
    UIApplication.shared.isIdleTimerDisabled = on
  }

  // MARK: - the call line

  private var callLine: some View {
    HStack(spacing: 4) {
      Button("Done", action: onDone).padding(.trailing, 4)
      TimelineView(.periodic(from: .now, by: 1)) { context in
        Text(call.status(now: context.date))
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(call.snapshot.endedBadly ? .red : .secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .accessibilityIdentifier("call-status")
      }
      Spacer(minLength: 4)
      if call.snapshot.isActive {
        voiceControl
        iconButton("arrow.clockwise", label: "Restart call", color: .primary) { call.restart() }
        iconButton("phone.down.fill", label: "Hang up", color: hangUpRed) { call.hangUp(from: "call_line") }
      }
    }
    .padding(.horizontal, 12)
    .frame(minHeight: 44)
  }

  /// The voice control is the mute: a disc that swells with Igor's voice; muted, it dims, freezes and is slashed.
  private var voiceControl: some View {
    Button(action: call.toggleMute) {
      ZStack {
        Circle().fill(Color.accentColor.opacity(0.25))
          .frame(width: 30, height: 30)
          .scaleEffect(call.snapshot.muted ? 0.6 : 0.5 + 0.5 * call.level)
          .animation(.linear(duration: 0.1), value: call.level)
        Image(systemName: call.snapshot.muted ? "mic.slash.fill" : "mic.fill")
          .foregroundStyle(call.snapshot.muted ? .red : .primary)
      }
      .opacity(call.snapshot.muted ? 0.5 : 1)
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
    }
    .accessibilityLabel(call.snapshot.muted ? "Unmute" : "Mute")
  }

  private func iconButton(_ symbol: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol).foregroundStyle(color).frame(width: 44, height: 44).contentShape(Rectangle())
    }
    .accessibilityLabel(label)
  }

  // MARK: - the body

  @ViewBuilder private var content: some View {
    switch call.snapshot.state {
    case .connecting:
      calling
    case .live:
      liveLine
      problemBanner
      captions
    case .idle, .ended:
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if call.snapshot.state == .ended { ending }
          picker
          Button {
            call.start(from: "call_screen")
          } label: {
            Label("Call Larry", systemImage: "phone.fill")
              .font(.title2.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 14)
          }
          .buttonStyle(.borderedProminent)
          .tint(.green)
          .accessibilityIdentifier("call-larry")
          if !call.snapshot.captions.isEmpty {
            VStack(alignment: .leading, spacing: 8) { ForEach(call.snapshot.captions) { captionRow($0) } }
          }
          diagnostics
        }
        .padding()
      }
    }
  }

  /// The way the Phone app calls: a ring pulsing around a handset; still under Reduce Motion.
  private var calling: some View {
    VStack(spacing: 18) {
      Spacer()
      PulseRing(still: reduceMotion)
      Text("Calling Larry…").font(.title2.weight(.semibold))
      Text(call.snapshot.backend?.label ?? "").foregroundStyle(.secondary)
      Spacer()
      diagnostics.padding(.horizontal)
    }
    .frame(maxWidth: .infinity)
  }

  /// What the recognizer hears Igor saying right now, big, before it is sent (story 084).
  private var liveLine: some View {
    let pending = call.snapshot.captions.last { $0.who == .igor && $0.pending }
    let text = call.snapshot.muted ? "muted" : (pending?.text ?? "")
    return ScrollViewReader { proxy in
      ScrollView {
        Text(text.isEmpty ? "listening…" : text)
          .font(.title2)
          .foregroundStyle(text.isEmpty ? .tertiary : .primary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .id("live")
      }
      .frame(height: 76)
      .padding(.horizontal, 12)
      .background(Color(.secondarySystemBackground))
      .onChange(of: text) { _, _ in proxy.scrollTo("live", anchor: .bottom) }
    }
  }

  @ViewBuilder private var problemBanner: some View {
    if let problem = call.snapshot.problem {
      HStack {
        Image(systemName: "exclamationmark.triangle.fill")
        Text(problem).font(.callout)
        Spacer()
        Button("Copy") { call.copyDiagnostics() }.font(.callout)
      }
      .foregroundStyle(.orange)
      .padding(.horizontal, 12).padding(.vertical, 6)
    }
  }

  private var captions: some View {
    let rows = call.snapshot.captions.filter { !($0.who == .igor && $0.pending) }
    return ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if rows.isEmpty { Text("Say hello.").foregroundStyle(.secondary) }
          ForEach(rows) { captionRow($0).id($0.id) }
          diagnostics.padding(.top, 12)
        }
        .padding(12)
      }
      .onChange(of: call.snapshot.captions) { _, _ in
        if let last = rows.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
      }
    }
  }

  private func captionRow(_ row: CaptionRow) -> some View {
    let isTool = row.who == .tool
    return HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label(row.who)).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
      Text(row.text)
        .foregroundStyle(row.who == .note || isTool ? .secondary : .primary)
        .lineLimit(isTool && !expanded.contains(row.id) ? 2 : nil)
        .onTapGesture {
          guard isTool else { return }
          if expanded.contains(row.id) { expanded.remove(row.id) } else { expanded.insert(row.id) }
        }
    }
  }

  /// Never wider than five characters: Igor, Tony — the voice — and Larry for what Larry put in himself.
  private func label(_ who: CaptionWho) -> String {
    switch who {
    case .igor: return "Igor"
    case .larry: return "Tony"
    case .tool, .note: return "Larry"
    }
  }

  @ViewBuilder private var ending: some View {
    if call.snapshot.endedBadly {
      VStack(alignment: .leading, spacing: 6) {
        Text(call.snapshot.endedReason ?? "the call failed").foregroundStyle(.red)
        Button(copied ? "Copied" : "Copy error") {
          call.copyDiagnostics()
          copied = true
        }
        .font(.callout)
      }
      .accessibilityIdentifier("call-error")
    }
  }

  private var picker: some View {
    VStack(alignment: .leading, spacing: 10) {
      Picker("Backend", selection: $call.backend) {
        ForEach(CallBackend.allCases, id: \.self) { Text($0.label).tag($0) }
      }
      .pickerStyle(.segmented)
      if CallVoice.hasPick(call.backend) {
        Picker("Voice", selection: $call.voice) {
          ForEach(CallVoice.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
      }
      Text(CallVoice.hasPick(call.backend) ? "\(call.route) · \(call.voice.label)" : call.route)
        .font(.footnote).foregroundStyle(.secondary)
        .accessibilityIdentifier("call-devices")
    }
  }

  // MARK: - diagnostics

  private var diagnostics: some View {
    DisclosureGroup("Diagnostics", isExpanded: $diagnosticsOpen) {
      VStack(alignment: .leading, spacing: 8) {
        Text("route: \(call.route)").font(.caption.monospaced())
        HStack {
          Button(copied ? "Copied" : "Copy diagnostics") {
            call.copyDiagnostics()
            copied = true
            Task {
              try? await Task.sleep(for: .seconds(1.5))
              copied = false
            }
          }
          if call.hasToken {
            Button(uploadLabel) { call.uploadTapped() }.disabled(call.upload == .uploading)
          }
        }
        .buttonStyle(.bordered)
        if let error = call.uploadError, call.upload == .failed || call.upload == .idle {
          Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
        }
        if let url = call.lastUploadURL {
          Text(url).font(.caption).textSelection(.enabled)
        }
        if diagnosticsOpen {
          let _ = call.logVersion
          Text(call.events.lines.suffix(400).joined(separator: "\n"))
            .font(.system(size: 10, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .accessibilityIdentifier("call-diagnostics")
  }

  private var uploadLabel: String {
    switch call.upload {
    case .idle: return "Upload"
    case .uploading: return "Uploading…"
    case .uploaded: return "Uploaded"
    case .failed: return "Upload failed"
    }
  }
}

private struct PulseRing: View {
  let still: Bool
  @State private var on = false

  var body: some View {
    ZStack {
      Circle().stroke(Color.green.opacity(0.5), lineWidth: 3)
        .frame(width: 120, height: 120)
        .scaleEffect(still ? 1 : (on ? 1.5 : 1))
        .opacity(still ? 1 : (on ? 0 : 1))
      Circle().fill(Color.green).frame(width: 96, height: 96)
      Image(systemName: "phone.fill").font(.system(size: 40)).foregroundStyle(.white)
    }
    .frame(width: 180, height: 180)
    .onAppear {
      guard !still else { return }
      withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { on = true }
    }
  }
}
