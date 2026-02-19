import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var shortcuts: [ShortcutItem] = []
    @Published var progress: [String: ProgressItem] = [:]
    @Published var dailyQueue: [ShortcutItem] = []
    @Published var currentIndex: Int = 0
    @Published var lastAnswerCorrect: Bool? = nil
    @Published var lastAnswerExpected: String = ""
    @Published var lastAnswerReceived: String = ""
    @Published var sessionStartedAt: Date? = nil

    private let progressFile = "progress_live12_macos.json"

    var currentItem: ShortcutItem? {
        guard currentIndex >= 0, currentIndex < dailyQueue.count else { return nil }
        return dailyQueue[currentIndex]
    }

    init() {
        loadDataset()
        loadProgress()
        ensureProgressForAll()
        startDailySession()
    }

    func loadDataset() {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "shortcuts_live12_macos", withExtension: "json", subdirectory: "Data"),
            Bundle.main.url(forResource: "shortcuts_live12_macos", withExtension: "json"),
            Bundle.main.url(forResource: "ableton_live12_shortcuts_macos_v0", withExtension: "json", subdirectory: "Data"),
            Bundle.main.url(forResource: "ableton_live12_shortcuts_macos_v0", withExtension: "json")
        ]

        for url in candidates.compactMap({ $0 }) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(ShortcutDataset.self, from: data)
                if !decoded.shortcuts.isEmpty {
                    shortcuts = decoded.shortcuts
                    return
                }
            } catch {
                continue
            }
        }
        shortcuts = []
    }

    func appSupportDir() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("AbletonShortcutTrainer", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func progressURL() -> URL {
        appSupportDir().appendingPathComponent(progressFile)
    }

    func loadProgress() {
        let url = progressURL()
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            let decoded = try JSONDecoder().decode([ProgressItem].self, from: data)
            var map: [String: ProgressItem] = [:]
            for p in decoded { map[p.id] = p }
            progress = map
        } catch { }
    }

    func saveProgress() {
        let url = progressURL()
        let list = Array(progress.values)
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(list)
            try data.write(to: url, options: [.atomic])
        } catch { }
    }

    func ensureProgressForAll() {
        for s in shortcuts {
            if progress[s.id] == nil {
                progress[s.id] = ProgressItem.new(id: s.id)
            }
        }
        saveProgress()
    }

    func dueItems(limit: Int) -> [ShortcutItem] {
        let now = Date()
        let due = trainableShortcuts().filter { s in
            guard let p = progress[s.id] else { return false }
            return p.dueAt <= now
        }
        // Sort due items by oldest due first
        let sorted = due.sorted { (a, b) in
            (progress[a.id]?.dueAt ?? .distantPast) < (progress[b.id]?.dueAt ?? .distantPast)
        }
        return Array(sorted.prefix(limit))
    }

    func newItems(limit: Int) -> [ShortcutItem] {
        // Define "new" as intervalDays == 0 and attempts == 0
        let items = trainableShortcuts().filter { s in
            guard let p = progress[s.id] else { return false }
            return p.attempts == 0
        }
        return Array(items.shuffled().prefix(limit))
    }

    func trainableShortcuts() -> [ShortcutItem] {
        shortcuts.filter { !KeyParse.parseExpected($0.mac_keys).isEmpty }
    }

    func startDailySession() {
        sessionStartedAt = Date()
        lastAnswerCorrect = nil
        lastAnswerExpected = ""
        lastAnswerReceived = ""

        // Default: 10 new + 30 due
        let due = dueItems(limit: 30)
        let dueIDs = Set(due.map(\.id))
        let fresh = newItems(limit: 10).filter { !dueIDs.contains($0.id) }
        var q = due + fresh

        // If queue is empty, add some random review
        if q.isEmpty {
            q = Array(trainableShortcuts().shuffled().prefix(30))
        }

        dailyQueue = q
        currentIndex = 0
    }

    func submitAnswer(received: KeyStroke, ms: Double) {
        guard let item = currentItem else { return }
        let expected = KeyParse.parseExpected(item.mac_keys)

        let isCorrect: Bool = expected.contains(where: { exp in
            // Special: Arrow accepts any arrow key without modifiers
            if exp.key == "Arrow" {
                return ["Left","Right","Up","Down"].contains(received.key) && !received.cmd && !received.option && !received.shift && !received.control
            }
            return exp.key == received.key
                && exp.cmd == received.cmd
                && exp.option == received.option
                && exp.shift == received.shift
                && exp.control == received.control
        })

        lastAnswerCorrect = isCorrect
        lastAnswerExpected = expected.map { $0.normalizedString() }.joined(separator: " OR ")
        lastAnswerReceived = received.normalizedString()

        updateProgress(id: item.id, correct: isCorrect, ms: ms)
        saveProgress()

        // Auto-advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.next()
        }
    }

    func updateProgress(id: String, correct: Bool, ms: Double) {
        guard var p = progress[id] else { return }
        p.attempts += 1
        if correct { p.correct += 1 }

        // Update avg ms (simple running avg)
        if p.attempts == 1 {
            p.avgMs = ms
        } else {
            p.avgMs = (p.avgMs * Double(p.attempts - 1) + ms) / Double(p.attempts)
        }

        if correct {
            p.correctStreak += 1
            // SM-2-ish scheduling
            if p.intervalDays == 0 { p.intervalDays = 1 }
            else if p.intervalDays == 1 { p.intervalDays = 3 }
            else { p.intervalDays = Int(Double(p.intervalDays) * p.ease) }

            p.ease = min(3.0, p.ease + 0.05)
        } else {
            p.correctStreak = 0
            p.intervalDays = 1
            p.ease = max(1.3, p.ease - 0.2)
        }

        p.dueAt = Calendar.current.date(byAdding: .day, value: p.intervalDays, to: Date()) ?? Date()
        progress[id] = p
    }

    func next() {
        if currentIndex < dailyQueue.count - 1 {
            currentIndex += 1
        } else {
            // session complete
            currentIndex = dailyQueue.count
        }
    }

    func restartSession() {
        startDailySession()
    }

    func accuracy() -> Double {
        let all = progress.values
        let attempts = all.reduce(0) { $0 + $1.attempts }
        if attempts == 0 { return 0 }
        let correct = all.reduce(0) { $0 + $1.correct }
        return Double(correct) / Double(attempts)
    }

    func masteredCount() -> Int {
        // Mastered = intervalDays >= 30 and correctStreak >= 3
        progress.values.filter { $0.intervalDays >= 30 && $0.correctStreak >= 3 }.count
    }
}
