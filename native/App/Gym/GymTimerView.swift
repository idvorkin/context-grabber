//  The Gym Timer screen (stories 100–116): rounds, a stopwatch and a set counter on a black gym-clock face,
//  with the accessory-work log underneath. Few large targets; turned on its side, only the time.

import ContextCore
import SwiftUI
import UIKit

private let chip = Color(red: 0.086, green: 0.129, blue: 0.243)
private let accent = Color(red: 0.263, green: 0.38, blue: 0.933)
private let stopRed = Color(red: 0.902, green: 0.224, blue: 0.275)
private let dim = Color(white: 0.53)

struct GymTimerView: View {
  @StateObject private var model: GymTimerModel
  @Environment(\.scenePhase) private var scenePhase
  @State private var showAccessory = false
  @State private var showSettings = false
  @State private var logged = false
  @State private var copied = false
  private let launch: GymTimerLaunch
  private let onExit: () -> Void

  init(app: AppModel, launch: GymTimerLaunch, onExit: @escaping () -> Void) {
    _model = StateObject(wrappedValue: GymTimerModel(log: app.log, database: app.database, liveActivity: app.liveActivity))
    self.launch = launch
    self.onExit = onExit
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if model.turn == .upright { upright } else { turned }
    }
    .preferredColorScheme(.dark)
    .sheet(isPresented: $showAccessory) {
      AccessorySheet(model: model) { count in
        guard count > 0 else { return }
        logged = true
        Task {
          try? await Task.sleep(for: .milliseconds(1800))
          logged = false
        }
      }
    }
    .sheet(isPresented: $showSettings) { TimerSettingsSheet(model: model) }
    .onAppear {
      model.appear(forcedTurn: launch.turn)
      if let voice = launch.voice { model.useCountVoiceOnce(voice) }
      if launch.settings { openSettings(from: "hook") }
      if let preset = launch.preset { model.choosePreset(preset) }
      if let custom = launch.custom { model.useCustomOnce(custom) }
      if launch.autostart { model.toggleTimer() }
    }
    .onDisappear { model.disappear() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { model.catchUp() }
    }
  }

  private func openSettings(from source: String) {
    model.openedSettings(from: source)
    showSettings = true
  }

  // MARK: - upright: the whole screen

  private var upright: some View {
    VStack(spacing: 0) {
      HStack(spacing: 16) {
        Button("Done", action: onExit).font(.system(size: 16, weight: .semibold)).foregroundStyle(accent)
        Spacer()
        Button {
          openSettings(from: "button")
        } label: {
          Image(systemName: "gearshape").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(white: 0.45))
        }
        .accessibilityLabel("Timer settings")
        .accessibilityIdentifier("timer-settings")
        Button(copied ? "Copied" : "Log") {
          UIPasteboard.general.string = model.timerLogText()
          copied = true
          Task {
            try? await Task.sleep(for: .milliseconds(1500))
            copied = false
          }
        }
        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(white: 0.33))
        .accessibilityLabel("Copy timer log")
      }
      .overlay { Text("Gym Timer").font(.system(size: 18, weight: .bold)).foregroundStyle(LED.white) }
      .padding(.horizontal, 16).padding(.vertical, 12)
      .overlay(alignment: .bottom) { chip.frame(height: 1) }

      if model.mode == .rounds { presetRow }

      GeometryReader { geo in
        VStack {
          Spacer(minLength: 0)
          switch model.mode {
          case .rounds: RoundsMode(model: model, dial: launch.dial ?? .shipped, width: geo.size.width - 48)
          case .stopwatch: StopwatchMode(model: model, width: geo.size.width - 48)
          case .sets: SetsMode(model: model, width: geo.size.width - 48)
          }
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
      }

      Button {
        showAccessory = true
      } label: {
        Text(logged ? "Logged ✓" : "＋ Log Accessory Work")
          .font(.system(size: 15, weight: .semibold)).foregroundStyle(LED.white)
          .padding(.horizontal, 20).padding(.vertical, 12)
          .background(logged ? Color(red: 0.024, green: 0.839, blue: 0.627) : chip, in: Capsule())
          .overlay(Capsule().stroke(logged ? .clear : accent, lineWidth: 1))
      }
      .padding(.bottom, 8)

      HStack(spacing: 0) {
        ForEach(GymMode.allCases, id: \.self) { mode in
          Button {
            model.mode = mode
          } label: {
            Text(mode.rawValue.uppercased())
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(model.mode == mode ? accent : Color(white: 0.33))
              .frame(maxWidth: .infinity).padding(.vertical, 14)
              .overlay(alignment: .top) { (model.mode == mode ? accent : chip).frame(height: model.mode == mode ? 2 : 1) }
          }
        }
      }
    }
  }

  private var presetRow: some View {
    HStack(spacing: 8) {
      ForEach(TimerProfile.presets.map { ($0.id, $0.label) } + [(CustomPreset.id, "CUSTOM")], id: \.0) { id, label in
        Button {
          model.choosePreset(id)
        } label: {
          Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(model.presetId == id ? .white : dim)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(model.presetId == id ? accent : chip, in: Capsule())
        }
      }
    }
    .padding(.vertical, 12)
    .disabled(model.locked)
    .opacity(model.locked ? 0.5 : 1)
  }

  // MARK: - turned: only the time

  /// RESET on its side (story 181): only while stopped with something to clear.
  private var roundsReset: (() -> Void)? {
    guard model.timer.isPaused || model.timer.phase == .done else { return nil }
    return { model.resetTimer() }
  }

  private var stopwatchReset: (() -> Void)? {
    guard model.stopwatch.isPaused else { return nil }
    return { model.resetStopwatch() }
  }

  @ViewBuilder private var turned: some View {
    switch model.mode {
    case .rounds:
      TurnedTimer(
        content: roundsFace(model), turn: model.turn,
        hint: model.timer.isRunning ? "tap to stop" : model.timer.isPaused ? "tap to resume" : "tap to start",
        onReset: roundsReset,
        onTap: model.toggleTimer)
    case .stopwatch:
      TimelineView(.animation(paused: !model.stopwatch.isRunning)) { timeline in
        TurnedTimer(
          content: stopwatchFace(model, at: timeline.date), turn: model.turn,
          hint: model.stopwatch.isRunning ? "tap to stop" : model.stopwatch.isPaused ? "tap to resume" : "tap to start",
          onReset: stopwatchReset,
          onTap: model.toggleStopwatch)
      }
    case .sets:
      let maxed = model.sets >= SetCounter.max
      TurnedTimer(
        content: FaceContent(time: String(model.sets), color: LED.green, sub: maxed ? "max reached" : ""),
        turn: model.turn, hint: maxed ? "max reached" : "tap to count",
        onTap: { model.setSets(model.sets + 1) })
    }
  }
}

/// How the screen was asked for: by hand, or by a link or launch hook that names a preset and starts it.
struct GymTimerLaunch: Equatable {
  var preset: String?
  var custom: CustomPreset?
  var autostart = false
  var turn: DeviceTurn?
  /// A launch hook's count voice: this visit only (story 182).
  var voice: CountVoice?
  /// A launch hook: open with Timer settings up, for a screenshot.
  var settings = false
  /// A launch hook (`GRABBER_TIMER_DIAL`): which Custom control to draw upright (story 184); the drums otherwise.
  var dial: DialStyle?
}

@MainActor private func roundsFace(_ model: GymTimerModel) -> FaceContent {
  let t = model.timer
  return FaceContent(
    word: SevenSegment.phaseWord(t.phase), paused: t.isPaused,
    time: formatMinutesSeconds(t.phase == .idle ? model.profile.workTime : t.timeLeft),
    color: LED.color(for: t.phase), sub: "Round \(t.currentRound) of \(t.totalRounds)")
}

@MainActor private func stopwatchFace(_ model: GymTimerModel, at date: Date) -> FaceContent {
  let time = Stopwatch.format(ms: model.stopwatchMs(at: date))
  return FaceContent(
    paused: model.stopwatch.isPaused, time: time.main, fraction: time.fraction,
    color: model.stopwatch.isRunning ? LED.red : LED.white)
}

// MARK: - the three modes, upright

private struct RoundButton: View {
  let title: String
  var color = accent
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
        .frame(width: 84, height: 84).background(color, in: Circle())
    }
  }
}

private struct SideButton: View {
  let title: String
  var enabled = true
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(dim)
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(chip, in: RoundedRectangle(cornerRadius: 8))
    }
    .disabled(!enabled).opacity(enabled ? 1 : 0.3)
  }
}

private struct RoundsMode: View {
  @ObservedObject var model: GymTimerModel
  let dial: DialStyle
  let width: CGFloat

  var body: some View {
    VStack(spacing: 0) {
      if model.presetId == CustomPreset.id, dial != .sliders {
        CustomDials(model: model, style: dial, width: width)
          .disabled(model.locked).opacity(model.locked ? 0.35 : 1)
          .padding(.bottom, 16)
      } else if model.presetId == CustomPreset.id {
        VStack(spacing: 4) {
          StepSlider(
            label: "Work", value: model.custom.work, range: CustomPreset.workRange, step: CustomPreset.stepSeconds,
            format: formatMinutesSeconds
          ) { model.changeCustom(CustomPreset(work: $0, rest: model.custom.rest, rounds: model.custom.rounds)) }
          StepSlider(
            label: "Rest", value: model.custom.rest, range: CustomPreset.restRange, step: CustomPreset.stepSeconds,
            format: formatMinutesSeconds
          ) { model.changeCustom(CustomPreset(work: model.custom.work, rest: $0, rounds: model.custom.rounds)) }
          StepSlider(
            label: "Rounds", value: model.custom.rounds, range: CustomPreset.roundsRange, step: 1, format: { String($0) }
          ) { model.changeCustom(CustomPreset(work: model.custom.work, rest: model.custom.rest, rounds: $0)) }
        }
        .disabled(model.locked).opacity(model.locked ? 0.35 : 1)
        .padding(.bottom, 12)
      }
      // With the arc above it, the face gives up a little height so START stays on screen.
      TimerFace(content: roundsFace(model), width: width, maxHeight: model.presetId == CustomPreset.id && dial == .arc ? 100 : 150)
        // Story 183: upright the time is a button too, as it is with the phone on its side.
        .contentShape(Rectangle()).onTapGesture(perform: model.toggleTimer)
        .accessibilityIdentifier("timer-face")
      HStack(spacing: 16) {
        SideButton(title: "RESET", action: model.resetTimer)
        RoundButton(
          title: model.timer.isRunning ? "STOP" : model.timer.isPaused ? "RESUME" : "START",
          color: model.timer.isRunning ? stopRed : accent, action: model.toggleTimer)
      }
      .padding(.top, 32)
    }
    .padding(.horizontal, 24)
  }
}

private struct StopwatchMode: View {
  @ObservedObject var model: GymTimerModel
  let width: CGFloat

  var body: some View {
    VStack(spacing: 0) {
      TimelineView(.animation(paused: !model.stopwatch.isRunning)) { timeline in
        TimerFace(content: stopwatchFace(model, at: timeline.date), width: width, maxHeight: 130)
      }
      .contentShape(Rectangle()).onTapGesture(perform: model.toggleStopwatch)
      HStack(spacing: 16) {
        SideButton(title: "LAP", enabled: model.stopwatch.isRunning, action: model.lap)
        RoundButton(
          title: model.stopwatch.isRunning ? "STOP" : "START", color: model.stopwatch.isRunning ? stopRed : accent,
          action: model.toggleStopwatch)
        SideButton(title: "RESET", action: model.resetStopwatch)
      }
      .padding(.top, 32)
      if !model.stopwatch.laps.isEmpty {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(Array(model.stopwatch.laps.enumerated()), id: \.offset) { index, ms in
              let f = Stopwatch.format(ms: ms)
              HStack {
                Text("Lap \(model.stopwatch.laps.count - index)").foregroundStyle(dim)
                Spacer()
                Text(f.main + f.fraction).monospacedDigit().foregroundStyle(LED.white)
              }
              .font(.system(size: 14)).padding(.vertical, 6)
              .overlay(alignment: .bottom) { chip.frame(height: 1) }
            }
          }
        }
        .frame(maxHeight: 160).padding(.top, 24)
      }
    }
    .padding(.horizontal, 24)
  }
}

private struct SetsMode: View {
  @ObservedObject var model: GymTimerModel
  let width: CGFloat
  private let mark = Color(red: 0.298, green: 0.788, blue: 0.941)

  var body: some View {
    let maxed = model.sets >= SetCounter.max
    let tally = SetCounter.tally(model.sets)
    VStack(spacing: 0) {
      Button {
        model.setSets(model.sets + 1)
      } label: {
        VStack(spacing: 8) {
          if model.sets == 0 {
            Text("TAP TO COUNT").font(.system(size: 24, weight: .semibold)).foregroundStyle(Color(white: 0.33))
          } else {
            HStack(spacing: 16) {
              ForEach(0..<tally.groups, id: \.self) { _ in tallyGroup(4, struck: true) }
              if tally.remainder > 0 { tallyGroup(tally.remainder, struck: false) }
            }
          }
          if maxed {
            Text("MAX REACHED!").font(.system(size: 16, weight: .bold))
              .foregroundStyle(Color(red: 0.969, green: 0.145, blue: 0.522))
          }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(maxed)
      .accessibilityLabel("Sets: \(model.sets). Tap to add one.")
      TimerFace(content: FaceContent(time: String(model.sets), color: LED.green), width: width, maxHeight: 90)
      HStack(spacing: 16) {
        SideButton(title: "UNDO", enabled: model.sets > 0) { model.setSets(model.sets - 1) }
        RoundButton(title: "+1", color: maxed ? chip : accent) { model.setSets(model.sets + 1) }.disabled(maxed)
        SideButton(title: "RESET", enabled: model.sets > 0) { model.setSets(0) }
      }
      .padding(.top, 32)
    }
    .padding(.horizontal, 24)
  }

  private func tallyGroup(_ marks: Int, struck: Bool) -> some View {
    HStack(spacing: 4) {
      ForEach(0..<marks, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 2).fill(mark).frame(width: 4, height: 40)
      }
    }
    .overlay {
      if struck {
        GeometryReader { geo in
          Rectangle().fill(mark).frame(width: geo.size.width * 1.3, height: 3)
            .rotationEffect(.degrees(-30)).position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
      }
    }
  }
}

/// A label, its value, and a slider that snaps to a step with − and + at the ends (story 101).
private struct StepSlider: View {
  let label: String
  let value: Int
  let range: ClosedRange<Int>
  let step: Int
  let format: (Int) -> String
  let onChange: (Int) -> Void

  var body: some View {
    VStack(spacing: 2) {
      HStack {
        Text(label.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(1).foregroundStyle(dim)
        Spacer()
        Text(format(value)).font(.system(size: 14, weight: .bold)).monospacedDigit().foregroundStyle(LED.white)
      }
      HStack(spacing: 10) {
        stepButton("−", by: -step).accessibilityLabel("\(label) less")
        Slider(
          value: Binding(get: { Double(value) }, set: { set(Int($0.rounded())) }),
          in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step)
        )
        .tint(accent)
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        stepButton("+", by: step).accessibilityLabel("\(label) more")
      }
    }
  }

  private func set(_ next: Int) {
    let clamped = min(range.upperBound, max(range.lowerBound, next))
    if clamped != value { onChange(clamped) }
  }

  private func stepButton(_ title: String, by delta: Int) -> some View {
    Button {
      set(value + delta)
    } label: {
      Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(LED.white)
        .frame(width: 32, height: 32).background(chip, in: Circle())
    }
  }
}

// MARK: - Timer settings

/// The gear's sheet (story 182): who says the count. A tap chooses, remembers and plays that voice's "go".
private struct TimerSettingsSheet: View {
  @ObservedObject var model: GymTimerModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          ForEach(CountVoice.allCases, id: \.self) { voice in
            Button {
              model.chooseCountVoice(voice)
            } label: {
              HStack {
                Text(voice.label).foregroundStyle(.primary)
                Spacer()
                if model.countVoice == voice {
                  Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(accent)
                }
              }
            }
            .tint(.primary)
            .accessibilityIdentifier("count-voice-\(voice.rawValue)")
            .accessibilityAddTraits(model.countVoice == voice ? .isSelected : [])
          }
        } header: {
          Text("Count voice")
        } footer: {
          Text("Tap a voice to hear its “go”. The next cue uses it.")
        }
      }
      .navigationTitle("Timer settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.bold() }
      }
    }
    .presentationDetents([.medium])
  }
}

// MARK: - the accessory log sheet

/// The post-workout checklist (stories 112, 113): tap items, Save records the checked ones with the moment of
/// saving, Cancel records nothing. Starts empty each time; the last seven days sit underneath.
private struct AccessorySheet: View {
  @ObservedObject var model: GymTimerModel
  let onSaved: (Int) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var checked: Set<String> = []
  @State private var history: [AccessoryLogDay] = []
  @State private var error = ""
  @State private var historyError = ""

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(AccessoryLog.items, id: \.id) { item in
            Button {
              if checked.contains(item.id) { checked.remove(item.id) } else { checked.insert(item.id) }
            } label: {
              HStack(spacing: 14) {
                Image(systemName: checked.contains(item.id) ? "checkmark.square.fill" : "square")
                  .font(.system(size: 24)).foregroundStyle(accent)
                Text(item.label).font(.system(size: 17, weight: .medium)).foregroundStyle(.primary)
              }
              .padding(.vertical, 6)
            }
            .accessibilityAddTraits(checked.contains(item.id) ? .isSelected : [])
          }
          if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }
        Section("Last \(AccessoryLog.windowDays) days") {
          if !historyError.isEmpty {
            Text(historyError).foregroundStyle(.red)
          } else if history.isEmpty {
            Text("Nothing logged in the last \(AccessoryLog.windowDays) days").foregroundStyle(.secondary)
          }
          ForEach(history, id: \.dateKey) { day in
            VStack(alignment: .leading, spacing: 4) {
              Text(day.label).font(.system(size: 14, weight: .bold))
              ForEach(day.sessions, id: \.loggedAt) { session in
                Text("\(session.time) · \(session.items.joined(separator: ", "))")
                  .font(.system(size: 14)).foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      .navigationTitle("Log Accessory Work")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).bold() }
      }
    }
    .presentationDetents([.large])
    .onAppear {
      do { history = try model.accessoryHistory() } catch { historyError = "Could not read the log: \(error)" }
    }
  }

  private func save() {
    // Checklist order, whatever order they were tapped in; nothing checked records nothing.
    let ids = AccessoryLog.items.map(\.id).filter(checked.contains)
    guard !ids.isEmpty else { return dismiss() }
    do {
      onSaved(try model.saveAccessory(ids))
      dismiss()
    } catch {
      self.error = "Could not save: \(error)"
    }
  }
}
