import AppKit
import PomodoroCore
import SwiftUI

struct TimerView: View {
    @ObservedObject var store: TimerStore
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(store.engine.isQuickSession
                     ? "FOCUS · QUICK"
                     : (store.sessionPhase == .focus ? "FOCUS" : "BREAK"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("Session \(store.engine.completedFocusSessions + 1)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("Session type", selection: Binding(
                get: { store.sessionPhase == .focus },
                set: { store.selectMode(focus: $0) }
            )) {
                Text("Focus").tag(true)
                Text("Break").tag(false)
            }
            .pickerStyle(.segmented)
            .disabled(!store.engine.isIdle)
            if store.canEditDuration {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("Minutes", text: $store.durationText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .monospacedDigit().multilineTextAlignment(.center)
                        .accessibilityLabel("Session duration in minutes")
                        .onSubmit {
                            if store.engine.nextPhase != nil { store.confirmNextPhase() }
                            else { store.toggle() }
                        }
                    Text("min").foregroundStyle(.secondary)
                }
                if store.durationSeconds == nil {
                    Text("Enter a whole number from 1 to 180 minutes.")
                        .font(.caption).foregroundStyle(.red)
                } else {
                    Text("This session only · default \(Int(store.engine.settings.duration(for: store.sessionPhase) / 60)) min")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text(store.timeLabel).font(.system(size: 56, weight: .light, design: .rounded))
                    .monospacedDigit().frame(maxWidth: .infinity)
                    .accessibilityLabel("\(store.timeLabel) remaining")
            }
            if let next = store.engine.nextPhase {
                Text("\(store.engine.phase.title) complete. Ready for \(next.title.lowercased())?")
                    .font(.callout)
                Button(next == .focus ? "Start Focus" : "Start Break") { store.confirmNextPhase() }
                    .disabled(store.durationSeconds == nil)
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .frame(maxWidth: .infinity)
                if next != .focus {
                    Button("Skip break") { store.skipBreak() }
                        .buttonStyle(.plain).foregroundStyle(.secondary).font(.caption)
                        .frame(maxWidth: .infinity)
                }
                Button("Reset") { store.reset() }
                    .buttonStyle(.plain).foregroundStyle(.secondary).font(.caption)
                    .help("Discard the pending transition to choose another session")
            } else {
                HStack {
                    Button(store.engine.isRunning ? "Pause" : "Start") { store.toggle() }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.engine.isIdle && store.durationSeconds == nil)
                    Button("Reset") { store.reset() }
                        .disabled(store.engine.isIdle)
                }.controlSize(.large).frame(maxWidth: .infinity)
            }
            Divider()
            HStack {
                Button(showSettings ? "Hide settings" : "Settings") { showSettings.toggle() }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }.font(.caption)
            if showSettings {
                Divider()
                Text("Durations apply to the next idle session.")
                    .font(.caption).foregroundStyle(.secondary)
                Group {
                    Stepper("Focus: \(store.focusMinutes) min", value: $store.focusMinutes, in: 1...120)
                    Stepper("Short break: \(store.shortMinutes) min", value: $store.shortMinutes, in: 1...60)
                    Stepper("Long break: \(store.longMinutes) min", value: $store.longMinutes, in: 1...90)
                    Stepper("Long break every \(store.longBreakEvery) focus sessions",
                            value: $store.longBreakEvery, in: 1...12)
                }.disabled(!store.canEditSettings)
                Toggle("Focus clock tick", isOn: $store.tickEnabled)
                HStack {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $store.tickVolume, in: 0...1) { editing in
                        if !editing { store.playTickPreview() }
                    }
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Tick volume")
                Button("Reset cycle count") { store.resetCycle() }
                    .disabled(store.engine.isRunning)
                Text("Reset cycle count also returns to focus.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 310)
    }
}

struct TransitionView: View {
    let phase: Phase
    let start: () -> Void
    let later: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 26) {
                Image(systemName: phase == .focus ? "brain.head.profile" : "cup.and.saucer")
                    .font(.system(size: 76)).foregroundStyle(.mint)
                Text(phase == .focus ? "Time to focus" : "Time for a break")
                    .font(.system(size: 50, weight: .semibold, design: .rounded))
                Text("The next timer starts only when you confirm.")
                    .font(.title3).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Button("Later", action: later).buttonStyle(.bordered).controlSize(.large)
                    Button(phase == .focus ? "Start Focus" : "Start Break", action: start)
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }.padding(.top, 16)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(40)
        }
    }
}
