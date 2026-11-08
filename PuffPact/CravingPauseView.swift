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
        // A neutral selection tap acknowledges input without rewarding smoking.
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

/// Native SwiftUI 3-minute craving pause view.
@MainActor
public struct CravingPauseView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var model = PauseModel()
    @State private var sheet: PauseSheet?
    @State private var sheetWasLog = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 56
    @AccessibilityFocusState private var logButtonFocused: Bool

    private enum PauseSheet: String, Identifiable {
        case log, end
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        Group {
            if verticalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize {
                // Keep every control reachable in landscape and at large text sizes.
                ScrollView {
                    VStack(spacing: 22) {
                        content
                        if model.undoableLog != nil { undoBanner }
                        actions
                    }
                    .padding(24)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ScrollView {
                    content
                        .padding(24)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 12) {
                        if model.undoableLog != nil { undoBanner }
                        actions
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .background(PauseTheme.canvas)
                }
            }
        }
        .background(PauseTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet, onDismiss: {
            if sheetWasLog { logButtonFocused = true }
        }) { presentedSheet in
            confirmationSheet(presentedSheet)
                .presentationDetents(dynamicTypeSize.isAccessibilitySize
                    ? [.large] : [.height(450), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(PauseTheme.surface)
        }
        .task { await runClock() }
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
            // Reconcile the real deadline immediately on returning to the app.
            model.tick(quotesEnabled: false)
        }
    }

    private var topBar: some View {
        HStack {
            Capsule()
                .fill(PauseTheme.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .overlay(alignment: .trailing) {
            Button {
                dismiss()
                state.isCravingTimerActive = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PauseTheme.secondary)
                    .frame(width: 30, height: 30)
                    .background(PauseTheme.surface, in: Circle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, 4)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            topBar
            heading
            timerCard
            quoteCard
            Label {
                Text("You don’t have to get it perfect.\nJust give yourself this moment.")
                    .font(.footnote)
                    .foregroundStyle(PauseTheme.secondary)
            } icon: {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(PauseTheme.green)
            }
            .padding(.horizontal, 4)

            Text("PuffPact · Cravings usually fade in 3–5 minutes")
                .font(.caption)
                .foregroundStyle(PauseTheme.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("YOUR MOMENT OF CALM", color: PauseTheme.gold)
            Text(model.heading)
                .font(.largeTitle.weight(.bold))
                .tracking(-1)
                .foregroundStyle(PauseTheme.cream)
                .accessibilityAddTraits(.isHeader)
            Text(model.clock.phase == .complete
                ? "Whatever comes next, you made space for yourself."
                : "Give yourself three minutes. There’s nowhere else you need to be.")
                .font(.subheadline)
                .foregroundStyle(PauseTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timerCard: some View {
        VStack(spacing: 20) {
            HStack {
                eyebrow("A LITTLE ROOM TO BREATHE")
                Spacer(minLength: 8)
                Image(systemName: "leaf")
                    .foregroundStyle(PauseTheme.green)
                    .accessibilityHidden(true)
            }

            if dynamicTypeSize.isAccessibilitySize {
                timerContents
                    .padding(.vertical, 12)
            } else {
                ring
            }

            Text(model.clock.phase == .complete
                ? "Be proud of showing up for yourself."
                : "Inhale a little calm. Exhale a little tension.")
                .font(.caption)
                .foregroundStyle(PauseTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(PauseTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private var ring: some View {
        ZStack {
            Circle()
                .fill(PauseTheme.green.opacity(reduceMotion ? 0.025 :
                    0.025 + model.breathExpansion * 0.06))
                .scaleEffect(reduceMotion ? 0.82 : 0.72 + model.breathExpansion * 0.16)
                .animation(reduceMotion ? nil : .linear(duration: 0.1),
                           value: model.clock.remaining)
                .accessibilityHidden(true)

            Circle().stroke(PauseTheme.track, lineWidth: 10)
                .accessibilityHidden(true)
            Circle()
                .trim(from: 0, to: model.clock.phase == .complete ? 1 : model.clock.progress)
                .stroke(PauseTheme.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.1),
                           value: model.clock.remaining)
                .accessibilityHidden(true)

            timerContents
                .padding(26)
        }
        .frame(maxWidth: 240)
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 8)
        // Do not announce every timer tick or changing breathing cue.
        .accessibilityElement(children: .contain)
    }

    private var timerContents: some View {
        VStack(spacing: 9) {
            Image(systemName: model.clock.phase == .complete ? "checkmark" : "leaf")
                .font(.title3)
                .foregroundStyle(PauseTheme.green.opacity(0.8))
                .accessibilityHidden(true)
            Text(model.clock.timeLabel)
                .font(.system(size: timerFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .foregroundStyle(PauseTheme.cream)
                .accessibilityLabel("Time remaining")
                .accessibilityValue(model.clock.timeLabel)
            Text(model.breathLabel)
                .font(.footnote)
                .foregroundStyle(PauseTheme.cream)
            Text(timerSubtitle)
                .font(.caption)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                eyebrow("A GENTLE REMINDER", color: PauseTheme.gold)
                Spacer()
                Image(systemName: "quote.opening")
                    .foregroundStyle(PauseTheme.gold)
                    .accessibilityHidden(true)
            }
            // Reserve the tallest quote's intrinsic height, including Dynamic Type.
            ZStack(alignment: .topLeading) {
                ForEach(model.quotes, id: \.self) { quote in
                    Text(quote).hidden().accessibilityHidden(true)
                }
                Text(model.quotes[model.quoteIndex])
                    .id(model.quoteIndex)
                    .transition(.opacity)
            }
            .font(.title3.weight(.medium))
            .foregroundStyle(PauseTheme.cream)
            .fixedSize(horizontal: false, vertical: true)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.quoteIndex)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.quotes[model.quoteIndex])

            HStack {
                Text("One moment at a time.")
                    .font(.caption)
                    .foregroundStyle(PauseTheme.secondary)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    ForEach(model.quotes.indices, id: \.self) { index in
                        Capsule()
                            .fill(PauseTheme.gold.opacity(index == model.quoteIndex ? 1 : 0.25))
                            .frame(width: index == model.quoteIndex ? 12 : 4, height: 4)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(22)
        .background(PauseTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(PauseTheme.gold.opacity(0.5), lineWidth: 1)
                .accessibilityHidden(true)
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button(action: handlePrimaryAction) {
                Label(model.primaryTitle, systemImage: model.primarySymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PauseButtonStyle(kind: .primary))

            if model.clock.phase == .running || model.clock.phase == .paused {
                Button("End session") {
                    sheetWasLog = false
                    sheet = .end
                }
                .font(.footnote)
                .foregroundStyle(PauseTheme.secondary)
                .frame(minHeight: 44)
            }
            if model.clock.phase == .complete {
                Button("Take another 3 minutes") { model.start() }
                    .font(.footnote)
                    .foregroundStyle(PauseTheme.cream)
                    .frame(minHeight: 44)
            }
            Button {
                sheetWasLog = true
                logButtonFocused = false
                sheet = .log
            } label: {
                Label("Log a cigarette", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PauseButtonStyle(kind: .secondary))
            .accessibilityFocused($logButtonFocused)

            if !dynamicTypeSize.isAccessibilitySize {
                Text("A cigarette doesn’t erase your progress.")
                    .font(.caption)
                    .foregroundStyle(PauseTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 3)
            }
        }
    }

    private var undoBanner: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text("Cigarette logged").font(.subheadline)
                Spacer(minLength: 8)
                undoControls
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Cigarette logged").font(.subheadline)
                undoControls
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .foregroundStyle(PauseTheme.cream)
        .background(PauseTheme.raised, in: RoundedRectangle(cornerRadius: 16))
    }

    private var undoControls: some View {
        HStack(spacing: 0) {
            Button("Undo", action: handleUndo)
                .underline()
                .font(.subheadline.weight(.medium))
                .frame(minWidth: 60, minHeight: 44)
            Button(action: model.dismissUndo) {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Dismiss notification")
        }
        .tint(PauseTheme.cream)
    }

    private func confirmationSheet(_ kind: PauseSheet) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: kind == .log ? "plus" : "leaf")
                        .font(.title2)
                        .foregroundStyle(PauseTheme.gold)
                        .frame(width: 52, height: 52)
                        .background(PauseTheme.raised, in: Circle())
                        .accessibilityHidden(true)
                    Spacer()
                    Button { sheet = nil } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(PauseTheme.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }
                VStack(alignment: .leading, spacing: 10) {
                    eyebrow(kind == .log ? "A RECORD, NOT A SETBACK" : "AT YOUR OWN PACE",
                            color: PauseTheme.gold)
                    Text(kind == .log ? "Log a cigarette?" : "End this pause?")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(PauseTheme.cream)
                        .accessibilityAddTraits(.isHeader)
                    Text(kind == .log
                        ? "Your progress still counts. This is just a moment, not the whole journey."
                        : "You can come back for another moment whenever you need one.")
                        .font(.subheadline)
                        .foregroundStyle(PauseTheme.secondary)
                }
                if kind == .log {
                    HStack {
                        Text("Time").foregroundStyle(PauseTheme.secondary)
                        Spacer()
                        Text("Now")
                    }
                    .font(.subheadline)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Divider() }
                }
                VStack(spacing: 6) {
                    Button {
                        if kind == .log {
                            handleLogCigarette()
                        } else {
                            model.reset()
                            dismiss()
                            state.isCravingTimerActive = false
                        }
                        sheet = nil
                    } label: {
                        Text(kind == .log ? "Confirm log" : "End session")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PauseButtonStyle(kind: .neutral))

                    Button(kind == .log ? "Cancel" : "Keep going") { sheet = nil }
                        .foregroundStyle(PauseTheme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    if kind == .log {
                        Text("This will be logged to your pact.")
                            .font(.caption)
                            .foregroundStyle(PauseTheme.secondary)
                    }
                }
            }
            .padding(24)
        }
    }

    private func eyebrow(_ text: String, color: Color = PauseTheme.secondary) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(1.7)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

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
            model.tick(quotesEnabled: scenePhase == .active && sheet == nil)
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
            .padding(.vertical, 16)
            .frame(minHeight: 54)
            .background(
                kind == .primary ? PauseTheme.green :
                    kind == .neutral ? PauseTheme.raised : PauseTheme.surface,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                if kind != .primary {
                    RoundedRectangle(cornerRadius: 16)
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
