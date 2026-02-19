import Foundation
import AppKit

struct KeyStroke: Hashable, Codable {
    var key: String
    var cmd: Bool
    var option: Bool
    var shift: Bool
    var control: Bool

    func normalizedString() -> String {
        var parts: [String] = []
        if control { parts.append("Ctrl") }
        if cmd { parts.append("Cmd") }
        if option { parts.append("Option") }
        if shift { parts.append("Shift") }
        parts.append(key)
        return parts.joined(separator: " + ")
    }
}

enum KeyParse {
    static func splitAlternatives(_ s: String) -> [String] {
        // Normalize separators: "or", "/", " or ", " / "
        let cleaned = s.replacingOccurrences(of: " or ", with: " OR ")
            .replacingOccurrences(of: " / ", with: " OR ")
            .replacingOccurrences(of: "/", with: " OR ")
        return cleaned.components(separatedBy: " OR ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func parseExpected(_ s: String) -> [KeyStroke] {
        // Accepts forms like "Cmd Option B", "Cmd + Option + B", "Space", "arrow keys"
        let alts = splitAlternatives(s)
        var out: [KeyStroke] = []
        for alt in alts {
            let lowered = alt.lowercased()
            if lowered.contains("arrow keys") {
                // treat as special; user must press any arrow key
                out.append(KeyStroke(key: "Arrow", cmd: false, option: false, shift: false, control: false))
                continue
            }

            // Skip non-keyboard/manual-instruction rows that cannot be answered by a single key press.
            if lowered.contains("click") || lowered.contains("drag") || lowered.contains("scroll") || lowered.contains("toggle between") {
                continue
            }

            let tokens = alt
                .replacingOccurrences(of: "+", with: " ")
                .replacingOccurrences(of: "Function", with: "Fn")
                .replacingOccurrences(of: "fn", with: "Fn")
                .split(separator: " ")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            var cmd = false, option = false, shift = false, control = false
            var keys: [String] = []

            for t in tokens {
                switch t {
                case "Cmd": cmd = true
                case "Option": option = true
                case "Shift": shift = true
                case "Ctrl": control = true
                default:
                    keys.append(t)
                }
            }

            // A valid shortcut alternative must contain exactly one non-modifier key token.
            guard keys.count == 1 else { continue }
            let key = keys[0]

            // Normalize common names
            let normalizedKey: String
            switch key.lowercased() {
            case "space": normalizedKey = "Space"
            case "tab": normalizedKey = "Tab"
            case "enter", "return": normalizedKey = "Enter"
            case "esc", "escape": normalizedKey = "Esc"
            case "delete", "del": normalizedKey = "Delete"
            case "home": normalizedKey = "Home"
            case "end": normalizedKey = "End"
            default: normalizedKey = key
            }

            out.append(KeyStroke(key: normalizedKey, cmd: cmd, option: option, shift: shift, control: control))
        }
        return out
    }

    static func parseEvent(_ event: NSEvent) -> KeyStroke? {
        guard event.type == .keyDown else { return nil }
        let flags = event.modifierFlags

        let cmd = flags.contains(.command)
        let option = flags.contains(.option)
        let shift = flags.contains(.shift)
        let control = flags.contains(.control)

        // Key mapping
        var key = ""
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            // Normalize letters to uppercase for display
            key = chars.uppercased()
        }

        // Special keys
        switch event.keyCode {
        case 36: key = "Enter"
        case 48: key = "Tab"
        case 49: key = "Space"
        case 51: key = "Delete"
        case 53: key = "Esc"
        case 115: key = "Home"
        case 119: key = "End"
        case 123: key = "Left"
        case 124: key = "Right"
        case 125: key = "Down"
        case 126: key = "Up"
        default:
            break
        }

        if key.isEmpty { return nil }
        return KeyStroke(key: key, cmd: cmd, option: option, shift: shift, control: control)
    }
}
