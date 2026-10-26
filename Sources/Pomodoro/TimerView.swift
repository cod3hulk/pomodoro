import AppKit
import PomodoroCore
import SwiftUI

struct TimerView: View {
    @ObservedObject var store: TimerStore
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(store.engine.phase.title.uppercased())
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("Session \(store.engine.completedFocusSessions + 1)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(store.timeLabel).font(.system(size: 56, weight: .light, design: .rounded))
                .monospacedDigit().frame(maxWidth: .infinity)
                .accessibilityLabel("\(store.timeLabel) remaining")
            if let next = store.engine.nextPhase {
                Text("\(store.engine.phase.title) complete. Ready for \(next.title.lowercased())?")
                    .font(.callout)
                Button("Start \(next.title)") { store.confirmNextPhase() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Button(store.engine.isRunning ? "Pause" : "Start") { store.toggle() }
                        .buttonStyle(.borderedProminent)
                    Button("Reset") { store.reset() }
                        .disabled(!store.engine.isRunning && store.remaining == store.engine.settings.duration(for: store.engine.phase))
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
                    Button("Start \(phase.title)", action: start)
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }.padding(.top, 16)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(40)
        }
    }
}
