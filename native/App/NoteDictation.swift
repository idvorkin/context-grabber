//  Speak the note (#239; story 142): the report sheet's microphone. What is said lands in the note as it is said,
//  after whatever was typed, recognised on the phone when it can be. The audio session is put back exactly as it
//  was afterwards, so music keeps playing and the Gym Timer's session carries on.

import AVFoundation
import Speech

@MainActor
final class NoteDictation: ObservableObject {
  @Published private(set) var listening = false
  /// Why the microphone cannot listen, shown under the note with Copy error; nil when it can.
  @Published private(set) var problem: MirrorProblem?

  private let log: SessionLog
  private let engine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var saved: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)?
  /// The note as it was when listening began; the words go after it.
  private var before = ""
  private var onText: ((String) -> Void)?

  init(log: SessionLog) { self.log = log }

  func toggle(note: String, onText: @escaping (String) -> Void) {
    if listening { stop(why: "tap") } else { start(note: note, onText: onText) }
  }

  private func start(note: String, onText: @escaping (String) -> Void) {
    problem = nil
    SFSpeechRecognizer.requestAuthorization { status in
      Task { @MainActor in
        guard status == .authorized else {
          self.fail("Speech recognition is off for Grabber Native (Settings › Grabber Native)", ["auth": "\(status.rawValue)"])
          return
        }
        AVAudioApplication.requestRecordPermission { granted in
          Task { @MainActor in
            guard granted else {
              self.fail("The microphone is off for Grabber Native (Settings › Grabber Native)", ["mic": "denied"])
              return
            }
            self.begin(note: note, onText: onText)
          }
        }
      }
    }
  }

  private func begin(note: String, onText: @escaping (String) -> Void) {
    guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
      fail("This phone cannot recognise speech right now", ["recognizer": "unavailable"])
      return
    }
    let session = AVAudioSession.sharedInstance()
    saved = (session.category, session.mode, session.categoryOptions)
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
    do {
      // Mixed, so music or a podcast playing underneath keeps playing.
      try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothHFP])
      try session.setActive(true)
      let input = engine.inputNode
      input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
        request.append(buffer)
      }
      engine.prepare()
      try engine.start()
    } catch {
      engine.inputNode.removeTap(onBus: 0)
      restoreSession()
      fail("The microphone would not start", ["error": "\(error)"])
      return
    }
    self.request = request
    self.onText = onText
    before = note.trimmingCharacters(in: .whitespacesAndNewlines)
    listening = true
    log.event("dictation_start", ["on_device": request.requiresOnDeviceRecognition, "route": AudioReset.state().line])
    task = recognizer.recognitionTask(with: request) { result, error in
      let text = result?.bestTranscription.formattedString
      let final = result?.isFinal ?? false
      Task { @MainActor in
        guard self.listening else { return }
        if let text { self.onText?(self.before.isEmpty ? text : "\(self.before) \(text)") }
        if let error, !final {
          self.log.event("dictation_error", ["error": "\(error)"])
          self.stop(why: "error")
        } else if final {
          self.stop(why: "final")
        }
      }
    }
  }

  /// Stops listening: a second tap, Log it, the sheet closing, the end of speech or an error.
  func stop(why: String) {
    guard listening else { return }
    listening = false
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    request?.endAudio()
    task?.finish()
    request = nil
    task = nil
    onText = nil
    restoreSession()
    log.event("dictation_stop", ["why": why])
  }

  private func restoreSession() {
    guard let saved else { return }
    self.saved = nil
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(saved.category, mode: saved.mode, options: saved.options)
      // Nothing of this app's was sounding before (the launch's quiet category): let go, so others resume.
      if saved.category == .ambient || saved.category == .soloAmbient {
        try session.setActive(false, options: .notifyOthersOnDeactivation)
      }
    } catch {
      log.event("error", ["where": "dictation_restore", "message": "\(error)"])
    }
  }

  private func fail(_ message: String, _ extra: [String: String]) {
    var fields = extra
    fields["route"] = AudioReset.state().line
    problem = MirrorProblem(message: message, context: "BugReportSheet.dictate", extra: fields)
    log.event("dictation_error", fields.merging(["message": message]) { a, _ in a })
  }
}
