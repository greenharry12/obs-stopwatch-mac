import SwiftUI

@MainActor
final class StopwatchModel: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var currentElapsed: TimeInterval = 0
    @Published private(set) var isRunning = false

    private var timer: Timer?
    private var startedAt: Date?
    private let outputURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("obs-stopwatch.txt")

    init() {
        writeCurrentValue()
    }


    var formatted: String {
        Self.format(currentElapsed)
    }

    static func format(_ elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startedAt = Date()
        currentElapsed = elapsed
        startTimer()
    }

    func pause() {
        guard isRunning else { return }
        if let startedAt {
            elapsed += Date().timeIntervalSince(startedAt)
        }
        currentElapsed = elapsed
        isRunning = false
        self.startedAt = nil
        stopTimer()
        writeCurrentValue()
    }

    func resume() {
        start()
    }

    func togglePauseResume() {
        isRunning ? pause() : resume()
    }

    func stop() {
        pause()
        elapsed = 0
        currentElapsed = 0
        writeCurrentValue()
    }

    func reset() {
        elapsed = 0
        currentElapsed = 0
        if isRunning {
            startedAt = Date()
        }
        writeCurrentValue()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isRunning, let startedAt else { return }
        let nowElapsed = elapsed + Date().timeIntervalSince(startedAt)
        currentElapsed = nowElapsed
        writeCurrentValue(formatted: Self.format(nowElapsed))
    }

    private func writeCurrentValue(formatted: String? = nil) {
        let value = formatted ?? Self.format(currentElapsed)
        do {
            try value.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed writing \(outputURL.path): \(error)")
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: StopwatchModel
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 18) {
            Text(model.formatted)
                .font(.system(size: 56, weight: .semibold, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                Button(model.isRunning ? "Pause" : "Start") {
                    model.togglePauseResume()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Stop") {
                    model.stop()
                }

                Button("Reset…") {
                    confirmReset = true
                }
                .foregroundStyle(.red)
            }

            Text("Writes to ~/obs-stopwatch.txt for OBS Text source")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 220)
        .confirmationDialog("Reset stopwatch to 00:00:00?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) {
                model.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the current elapsed time.")
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(model.isRunning ? "Pause" : "Resume") {
                    model.togglePauseResume()
                }
            }
            ToolbarItem(placement: .automatic) {
                Button("Reset…") {
                    confirmReset = true
                }
            }
        }
    }
}

@main
struct OBSStopwatchMacApp: App {
    @StateObject private var model = StopwatchModel()
    @State private var confirmMenuReset = false

    var body: some Scene {
        WindowGroup("OBS Stopwatch") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 540, height: 260)

        MenuBarExtra("OBS Stopwatch", systemImage: model.isRunning ? "stopwatch.fill" : "stopwatch") {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.formatted)
                    .font(.system(.title3, design: .monospaced))
                Button(model.isRunning ? "Pause" : "Resume") {
                    model.togglePauseResume()
                }
                Button("Stop") {
                    model.stop()
                }
                Button("Reset…") {
                    confirmMenuReset = true
                }
            }
            .padding(10)
            .confirmationDialog("Reset stopwatch?", isPresented: $confirmMenuReset) {
                Button("Reset", role: .destructive) {
                    model.reset()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
