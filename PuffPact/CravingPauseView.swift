//
//  CravingPauseView.swift
//  PuffPact
//

import Observation
import SwiftUI
import UIKit

private enum PauseTheme {
    static let canvas = Color(red: 11 / 255, green: 11 / 255, blue: 11 / 255)
    static let surface = Color(red: 23 / 255, green: 23 / 255, blue: 25 / 255)
    static let raised = Color(red: 38 / 255, green: 38 / 255, blue: 41 / 255)
    static let cream = Color(red: 245 / 255, green: 232 / 255, blue: 203 / 255)
    static let secondary = Color(red: 163 / 255, green: 163 / 255, blue: 163 / 255)
    static let green = Color(red: 129 / 255, green: 217 / 255, blue: 148 / 255)
    static let gold = Color(red: 217 / 255, green: 187 / 255, blue: 137 / 255)
    static let track = Color(red: 42 / 255, green: 42 / 255, blue: 46 / 255)
    static let border = Color(red: 119 / 255, green: 113 / 255, blue: 106 / 255)
}

@MainActor
@Observable
private final class PauseModel {
    struct Log: Identifiable {
        let id = UUID()
        let date: Date
    }

    private(set) var clock = SessionClock()
    private(set) var quoteIndex = 0
    private(set) var logs: [Log] = []
    private(set) var undoableLog: Log?
    private var previousTick = Date()
    private var quoteElapsed: TimeInterval = 0

    let quotes = [
        "You only need to focus on this moment.",
        "Let the urge be here without rushing to act.",
        "One slow breath is a place to start.",
        "You can choose your next small step.",
        "A difficult moment doesn’t erase your progress.",
        "Be gentle with yourself. Change takes practice."
    ]

    var heading: String {
        switch clock.phase {
        case .ready: "Let’s take a pause."
        case .running: "One breath at a time."
        case .paused: "Take your time."
        case .complete: "This pause counts."
        }
    }

    var primaryTitle: String {
        switch clock.phase {
        case .ready: "Start 3-minute pause"
        case .running: "Pause"
        case .paused: "Resume"
        case .complete: "Done"
        }
    }

    var primarySymbol: String {
        switch clock.phase {
        case .ready, .paused: "play.fill"
        case .running: "pause.fill"
        case .complete: "checkmark"
        }
    }

    var breathLabel: String {
        switch clock.phase {
        case .ready: "A moment, just for you"
        case .running: clock.elapsed.truncatingRemainder(dividingBy: 10) < 4
            ? "Breathe in" : "Breathe out"
        case .paused: "A moment to rest"
        case .complete: "You made space"
        }
    }

    var breathExpansion: Double {
        let phase = clock.elapsed.truncatingRemainder(dividingBy: 10)
        let linear = phase < 4 ? phase / 4 : 1 - (phase - 4) / 6
        return (1 - cos(.pi * linear)) / 2
    }

    func start(at now: Date = Date()) {
        clock.start(at: now)
        quoteElapsed = 0
        previousTick = now
        quoteIndex = 0
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        announce("Your three-minute pause has started.")
    }

    func primaryAction() {
        let now = Date()
        switch clock.phase {
        case .ready: start(at: now)
        case .running:
            clock.pause(at: now)
            UISelectionFeedbackGenerator().selectionChanged()
            announce(clock.phase == .complete ? "Your pause is complete." : "Session paused.")
        case .paused:
            clock.resume(at: now)
            previousTick = now
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            announce("Session resumed.")
        case .complete: reset()
        }
    }

    func tick(at now: Date = Date(), quotesEnabled: Bool) {
        let wasRunning = clock.phase == .running
        let delta = max(0, min(1, now.timeIntervalSince(previousTick)))
        previousTick = now
        clock.update(at: now)
        if wasRunning, clock.phase == .complete {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            announce("Your three-minute pause is complete.")
        }
        guard clock.phase == .running, quotesEnabled else { return }
        quoteElapsed += delta
        if quoteElapsed >= 20 {
            quoteElapsed = 0
            quoteIndex = (quoteIndex + 1) % quotes.count
        }
    }

    func reset() {
        clock.reset()
        quoteIndex = 0
        quoteElapsed = 0
        announce("Ready for a fresh pause whenever you are.")
    }

    func logCigarette() {
        let log = Log(date: Date())
        logs.append(log)
        undoableLog = log
        UISelectionFeedbackGenerator().selectionChanged()
        announce("Cigarette logged. Undo is available.")
    }

    func undo() {
        guard let log = undoableLog else { return }
        logs.removeAll { $0.id == log.id }
        undoableLog = nil
        announce("Cigarette log removed.")
    }

    func dismissUndo() { undoableLog = nil }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

/// Native minimal SwiftUI 3-minute craving pause view.
@MainActor
public struct CravingPauseView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var model = PauseModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                topBar
                heading
                ring
                quoteCard

                VStack(spacing: 8) {
                    if model.undoableLog != nil {
                        undoBanner
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    actions
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(PauseTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if model.clock.phase == .ready {
                model.start()
            }
        }
        .task {
            if model.clock.phase == .ready {
                model.start()
            }
            await runClock()
        }
        .task(id: model.undoableLog?.id) {
            guard model.undoableLog != nil else { return }
            do {
                try await Task.sleep(for: .seconds(8))
                model.dismissUndo()
            } catch {
                // Undo, replacement, or leaving the screen cancels expiry.
            }
        }
        .onChange(of: scenePhase) { _, _ in
            model.tick(quotesEnabled: false)
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Capsule()
                .fill(PauseTheme.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            Button {
                dismiss()
                state.isCravingTimerActive = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PauseTheme.secondary)
                    .frame(width: 28, height: 28)
                    .background(PauseTheme.surface, in: Circle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, 4)
    }

    private var heading: some View {
        VStack(spacing: 4) {
            Text(model.heading)
                .font(.title3.weight(.bold))
                .tracking(-0.3)
                .foregroundStyle(PauseTheme.cream)
                .accessibilityAddTraits(.isHeader)
            Text(model.clock.phase == .complete
                ? "Whatever comes next, you made space for yourself."
                : "Give yourself 3 minutes. The urge will pass.")
                .font(.caption)
                .foregroundStyle(PauseTheme.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .fill(PauseTheme.green.opacity(reduceMotion ? 0.03 :
                    0.03 + model.breathExpansion * 0.08))
                .scaleEffect(reduceMotion ? 0.88 : 0.76 + model.breathExpansion * 0.20)
                .animation(reduceMotion ? nil : .linear(duration: 0.1),
                           value: model.clock.remaining)
                .accessibilityHidden(true)

            Circle().stroke(PauseTheme.track, lineWidth: 8)
                .accessibilityHidden(true)

            Circle()
                .trim(from: 0, to: model.clock.phase == .complete ? 1 : model.clock.progress)
                .stroke(PauseTheme.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.1),
                           value: model.clock.remaining)
                .accessibilityHidden(true)

            timerContents
        }
        .frame(width: 175, height: 175)
        .accessibilityElement(children: .contain)
    }

    private var timerContents: some View {
        VStack(spacing: 4) {
            Image(systemName: model.clock.phase == .complete ? "checkmark" : "leaf")
                .font(.footnote)
                .foregroundStyle(PauseTheme.green.opacity(0.85))
                .accessibilityHidden(true)
            Text(model.clock.timeLabel)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(PauseTheme.cream)
                .accessibilityLabel("Time remaining")
                .accessibilityValue(model.clock.timeLabel)
            Text(model.breathLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PauseTheme.green)
            Text(timerSubtitle)
                .font(.caption2)
                .foregroundStyle(PauseTheme.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private var timerSubtitle: String {
        switch model.clock.phase {
        case .ready: "Ready when you are"
        case .running: "At your own pace"
        case .paused: "We’ll be here"
        case .complete: "One small step forward"
        }
    }

    private var quoteCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.caption2)
                .foregroundStyle(PauseTheme.gold.opacity(0.8))
                .accessibilityHidden(true)

            Text(model.quotes[model.quoteIndex])
                .font(.footnote.weight(.medium))
                .foregroundStyle(PauseTheme.cream)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .id(model.quoteIndex)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.quoteIndex)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.quotes[model.quoteIndex])

            Image(systemName: "quote.closing")
                .font(.caption2)
                .foregroundStyle(PauseTheme.gold.opacity(0.8))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(PauseTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(PauseTheme.gold.opacity(0.35), lineWidth: 1)
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button(action: handlePrimaryAction) {
                Label(model.primaryTitle, systemImage: model.primarySymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PauseButtonStyle(kind: .primary))

            Button(action: handleLogCigarette) {
                Label("Log a cigarette", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PauseButtonStyle(kind: .secondary))

            if model.clock.phase == .running || model.clock.phase == .paused {
                Button("End session") {
                    model.reset()
                    dismiss()
                    state.isCravingTimerActive = false
                }
                .font(.footnote)
                .foregroundStyle(PauseTheme.secondary)
                .frame(minHeight: 32)
            } else if model.clock.phase == .complete {
                Button("Take another 3 minutes") {
                    model.start()
                }
                .font(.footnote)
                .foregroundStyle(PauseTheme.cream)
                .frame(minHeight: 32)
            }
        }
    }

    private var undoBanner: some View {
        HStack {
            Text("Cigarette logged")
                .font(.footnote.weight(.medium))
            Spacer(minLength: 8)
            undoControls
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .foregroundStyle(PauseTheme.cream)
        .background(PauseTheme.raised, in: RoundedRectangle(cornerRadius: 12))
    }

    private var undoControls: some View {
        HStack(spacing: 0) {
            Button("Undo", action: handleUndo)
                .underline()
                .font(.footnote.weight(.bold))
                .frame(minWidth: 50, minHeight: 36)
            Button(action: model.dismissUndo) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Dismiss notification")
        }
        .tint(PauseTheme.cream)
    }

    // MARK: - Actions

    private func handlePrimaryAction() {
        if model.clock.phase == .complete {
            dismiss()
            state.isCravingTimerActive = false
        } else {
            model.primaryAction()
        }
    }

    private func handleLogCigarette() {
        model.logCigarette()
        state.logSmoke(for: state.currentUser.id, cravingUsed: true)
    }

    private func handleUndo() {
        model.undo()
        state.undoLastLog(for: state.currentUser.id)
    }

    private func runClock() async {
        while !Task.isCancelled {
            model.tick(quotesEnabled: scenePhase == .active)
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }
        }
    }
}

private struct PauseButtonStyle: ButtonStyle {
    enum Kind: Equatable { case primary, secondary, neutral }
    let kind: Kind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(kind == .primary ? PauseTheme.canvas : PauseTheme.cream)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(
                kind == .primary ? PauseTheme.green :
                    kind == .neutral ? PauseTheme.raised : PauseTheme.surface,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                if kind != .primary {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(PauseTheme.border, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16),
                       value: configuration.isPressed)
    }
}

#Preview {
    CravingPauseView()
        .environmentObject(AppState())
}
