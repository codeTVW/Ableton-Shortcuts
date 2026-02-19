import Foundation

struct ShortcutItem: Identifiable, Codable, Hashable {
    let id: String
    let action: String
    let mac_keys: String
    let windows_keys: String?
    let section: String
    let version: String?
    let os: String?
}

struct ShortcutDataset: Codable {
    struct Meta: Codable {
        let source: String?
        let source_pages: String?
        let generated_at: String?
        let os: String?
        let live_version: String?
        let count: Int?
        let note: String?
    }
    let meta: Meta?
    let shortcuts: [ShortcutItem]
}

struct ProgressItem: Codable {
    var id: String
    var ease: Double
    var intervalDays: Int
    var dueAt: Date
    var correctStreak: Int
    var attempts: Int
    var correct: Int
    var avgMs: Double

    static func new(id: String) -> ProgressItem {
        ProgressItem(
            id: id,
            ease: 2.3,
            intervalDays: 0,
            dueAt: Date(),
            correctStreak: 0,
            attempts: 0,
            correct: 0,
            avgMs: 0
        )
    }
}