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
        // Normalize only explicit separators, not literal slash keys.
        var cleaned = s.replacingOccurrences(of: " / ", with: " OR ")
        cleaned = cleaned.replacingOccurrences(of: " or ", with: " OR ", options: [.caseInsensitive])
        return cleaned.components(separatedBy: " OR ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
                .replacingOccurrences(of: "⌘", with: "Cmd")
                .replacingOccurrences(of: "⌥", with: "Option")
                .replacingOccurrences(of: "⇧", with: "Shift")
                .replacingOccurrences(of: "⌃", with: "Ctrl")
                .split(separator: " ")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            var cmd = false, option = false, shift = false, control = false
            var keys: [String] = []

            for t in tokens {
                switch t.lowercased() {
                case "cmd", "command": cmd = true
                case "option", "alt": option = true
                case "shift": shift = true
                case "ctrl", "control": control = true
                default:
                    keys.append(t)
                }
            }

            guard let key = normalizeKeyTokens(keys) else { continue }

            // Normalize common names
            let normalizedKey: String
            switch key.lowercased().replacingOccurrences(of: " ", with: "") {
            case "space": normalizedKey = "Space"
            case "tab": normalizedKey = "Tab"
            case "enter", "return": normalizedKey = "Enter"
            case "esc", "escape": normalizedKey = "Esc"
            case "delete", "del": normalizedKey = "Delete"
            case "backspace": normalizedKey = "Delete"
            case "home": normalizedKey = "Home"
            case "end": normalizedKey = "End"
            case "left", "leftarrow": normalizedKey = "Left"
            case "right", "rightarrow": normalizedKey = "Right"
            case "up", "uparrow": normalizedKey = "Up"
            case "down", "downarrow": normalizedKey = "Down"
            case "pageup": normalizedKey = "PageUp"
            case "pagedown": normalizedKey = "PageDown"
            default: normalizedKey = key
            }

            out.append(KeyStroke(key: normalizedKey, cmd: cmd, option: option, shift: shift, control: control))
        }
        return out
    }

    static func normalizeKeyTokens(_ tokens: [String]) -> String? {
        guard !tokens.isEmpty else { return nil }
        if tokens.count == 1 { return tokens[0] }

        let joined = tokens.joined(separator: " ").lowercased()
        switch joined {
        case "left arrow", "arrow left": return "Left"
        case "right arrow", "arrow right": return "Right"
        case "up arrow", "arrow up": return "Up"
        case "down arrow", "arrow down": return "Down"
        case "page up": return "PageUp"
        case "page down": return "PageDown"
        default:
            return nil
        }
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
        if let chars = event.characters, !chars.isEmpty {
            key = chars
        } else if let charsIgnoringMods = event.charactersIgnoringModifiers, !charsIgnoringMods.isEmpty {
            key = charsIgnoringMods
        }

        if key.count == 1, key.rangeOfCharacter(from: .letters) != nil {
            key = key.uppercased()
        }

        // Special keys
        switch event.keyCode {
        case 122: key = "F1"
        case 120: key = "F2"
        case 99: key = "F3"
        case 118: key = "F4"
        case 96: key = "F5"
        case 97: key = "F6"
        case 98: key = "F7"
        case 100: key = "F8"
        case 101: key = "F9"
        case 109: key = "F10"
        case 103: key = "F11"
        case 111: key = "F12"
        case 36: key = "Enter"
        case 48: key = "Tab"
        case 49: key = "Space"
        case 51: key = "Delete"
        case 53: key = "Esc"
        case 115: key = "Home"
        case 119: key = "End"
        case 116: key = "PageUp"
        case 121: key = "PageDown"
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
