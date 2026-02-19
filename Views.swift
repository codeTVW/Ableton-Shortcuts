import SwiftUI
import AppKit

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            TrainerView()
                .tabItem { Label("Train", systemImage: "keyboard") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "list.bullet") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .frame(minWidth: 900, minHeight: 560)
    }
}

struct HomeView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ableton Shortcut Trainer")
                .font(.largeTitle)
            Text("macOS, Live 12")

            HStack(spacing: 24) {
                StatCard(title: "Today queue", value: "\(store.dailyQueue.count)")
                StatCard(title: "Mastered", value: "\(store.masteredCount())")
                StatCard(title: "Accuracy", value: "\(Int(store.accuracy()*100))%")
            }

            HStack(spacing: 12) {
                Button("Start Daily Session") { store.startDailySession() }
                    .keyboardShortcut(.defaultAction)

                Button("Restart") { store.restartSession() }

                Spacer()

                Text("Tip: Use Cmd Shift D to start a session from the menu.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Data source: Ableton Live 12 Manual, Chapter 41.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .windowBackgroundColor)).shadow(radius: 1))
    }
}

struct TrainerView: View {
    @EnvironmentObject var store: AppStore
    @State private var lastKey: KeyStroke? = nil
    @State private var startedAt: Date? = nil
    @State private var monitor: Any? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trainer")
                    .font(.largeTitle)
                Spacer()
                Button("New Session") { store.startDailySession() }
            }

            if store.currentIndex >= store.dailyQueue.count {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Session complete.")
                        .font(.title2)
                    Text("Restart for a new queue.")
                        .foregroundStyle(.secondary)
                    Button("Restart") { store.restartSession() }
                }
                Spacer()
            } else {
                if let item = store.currentItem {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.action)
                            .font(.title)
                        Text(item.section)
                            .foregroundStyle(.secondary)

                        Divider()

                        HStack(spacing: 12) {
                            Text("Press the shortcut now.")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(store.currentIndex + 1)/\(store.dailyQueue.count)")
                                .foregroundStyle(.secondary)
                        }

                        KeyCaptureBox(lastKey: lastKey)

                        if let ok = store.lastAnswerCorrect {
                            FeedbackRow(ok: ok, expected: store.lastAnswerExpected, received: store.lastAnswerReceived)
                        } else {
                            Text(" ")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .textBackgroundColor)).shadow(radius: 1))
                }
                Spacer()
            }
        }
        .padding(20)
        .onAppear { installKeyMonitor() }
        .onDisappear { uninstallKeyMonitor() }
    }

    func installKeyMonitor() {
        uninstallKeyMonitor()
        startedAt = Date()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if let stroke = KeyParse.parseEvent(event) {
                lastKey = stroke
                let ms = (Date().timeIntervalSince(startedAt ?? Date())) * 1000.0
                startedAt = Date()
                store.submitAnswer(received: stroke, ms: ms)
                // prevent the keystroke from triggering UI actions
                return nil
            }
            return event
        }
    }

    func uninstallKeyMonitor() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

struct KeyCaptureBox: View {
    let lastKey: KeyStroke?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last input")
                .foregroundStyle(.secondary)
            Text(lastKey?.normalizedString() ?? "None yet")
                .font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }
}

struct FeedbackRow: View {
    let ok: Bool
    let expected: String
    let received: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ok ? "Correct" : "Wrong")
                .foregroundStyle(ok ? .green : .red)
                .font(.headline)
            Text("Expected: \(expected)")
                .foregroundStyle(.secondary)
            Text("You pressed: \(received)")
                .foregroundStyle(.secondary)
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var store: AppStore
    @State private var query: String = ""
    @State private var sectionFilter: String = "All"

    var sections: [String] {
        let s = Set(store.shortcuts.map { $0.section })
        return ["All"] + s.sorted()
    }

    var filtered: [ShortcutItem] {
        store.shortcuts.filter { item in
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = q.isEmpty || item.action.lowercased().contains(q.lowercased()) || item.mac_keys.lowercased().contains(q.lowercased())
            let matchesSection = sectionFilter == "All" || item.section == sectionFilter
            return matchesQuery && matchesSection
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Library")
                .font(.largeTitle)

            HStack(spacing: 10) {
                TextField("Search action or keys", text: $query)
                Picker("Section", selection: $sectionFilter) {
                    ForEach(sections, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 360)
            }

            Table(filtered) {
                TableColumn("Action") { Text($0.action) }
                TableColumn("Keys") { Text($0.mac_keys) }
                TableColumn("Section") { Text($0.section).foregroundStyle(.secondary) }
            }
        }
        .padding(20)
    }
}

struct StatsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.largeTitle)

            HStack(spacing: 24) {
                StatCard(title: "Total shortcuts", value: "\(store.shortcuts.count)")
                StatCard(title: "Attempts", value: "\(store.progress.values.reduce(0) { $0 + $1.attempts })")
                StatCard(title: "Accuracy", value: "\(Int(store.accuracy()*100))%")
            }

            Divider()

            List {
                Section("Weak shortcuts") {
                    ForEach(weakest(20), id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.action)
                            Text(item.mac_keys)
                                .foregroundStyle(.secondary)
                            Text(item.section)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
    }

    func weakest(_ n: Int) -> [ShortcutItem] {
        let pairs: [(ShortcutItem, Double)] = store.shortcuts.map { s in
            let p = store.progress[s.id] ?? ProgressItem.new(id: s.id)
            let acc = p.attempts == 0 ? 0.0 : Double(p.correct) / Double(p.attempts)
            return (s, acc)
        }
        return pairs.sorted { $0.1 < $1.1 }.prefix(n).map { $0.0 }
    }
}