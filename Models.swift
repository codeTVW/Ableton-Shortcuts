import Foundation

struct ShortcutItem: Identifiable, Decodable, Hashable {
    let id: String
    let action: String
    let mac_keys: String
    let windows_keys: String?
    let section: String
    let version: String?
    let os: String?

    enum CodingKeys: String, CodingKey {
        case id
        case action
        case mac_keys
        case windows_keys
        case section
        case category
        case version
        case os
    }

    init(id: String, action: String, mac_keys: String, windows_keys: String?, section: String, version: String?, os: String?) {
        self.id = id
        self.action = action
        self.mac_keys = mac_keys
        self.windows_keys = windows_keys
        self.section = section
        self.version = version
        self.os = os
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        action = try c.decode(String.self, forKey: .action)
        mac_keys = try c.decode(String.self, forKey: .mac_keys)
        windows_keys = try c.decodeIfPresent(String.self, forKey: .windows_keys)
        section = try c.decodeIfPresent(String.self, forKey: .section)
            ?? c.decodeIfPresent(String.self, forKey: .category)
            ?? "Uncategorized"
        version = try c.decodeIfPresent(String.self, forKey: .version)
        os = try c.decodeIfPresent(String.self, forKey: .os)
    }
}

struct ShortcutDataset: Decodable {
    struct Meta: Decodable {
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
