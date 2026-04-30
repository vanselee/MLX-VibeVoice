import Foundation

struct ParsedScript {
    let roles: [ParsedRole]
    let segments: [ParsedSegment]
    let unmarkedSegmentCount: Int
}

struct ParsedRole: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let normalizedName: String
}

struct ParsedSegment: Identifiable, Hashable {
    let id = UUID()
    let order: Int
    let roleName: String
    let text: String
    let wasUnmarked: Bool
}

enum ScriptParser {
    static func parse(_ text: String) -> ParsedScript {
        let rawLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var segments: [ParsedSegment] = []
        var roleNames: [String] = []
        var unmarkedCount = 0

        for rawLine in rawLines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let parsedLine = parseLine(line)
            if parsedLine.wasUnmarked {
                unmarkedCount += 1
            }

            let normalizedRole = normalizeRoleName(parsedLine.roleName)
            if !roleNames.contains(normalizedRole) {
                roleNames.append(normalizedRole)
            }

            segments.append(
                ParsedSegment(
                    order: segments.count + 1,
                    roleName: normalizedRole,
                    text: parsedLine.text,
                    wasUnmarked: parsedLine.wasUnmarked
                )
            )
        }

        if segments.isEmpty {
            roleNames = ["旁白"]
            segments = [
                ParsedSegment(
                    order: 1,
                    roleName: "旁白",
                    text: "在这里输入要配音的文案。",
                    wasUnmarked: true
                )
            ]
            unmarkedCount = 1
        }

        let roles = roleNames.map {
            ParsedRole(name: $0, normalizedName: normalizeRoleName($0))
        }

        return ParsedScript(
            roles: roles,
            segments: segments,
            unmarkedSegmentCount: unmarkedCount
        )
    }

    private static func parseLine(_ line: String) -> (roleName: String, text: String, wasUnmarked: Bool) {
        if let marker = bracketMarker(in: line, open: "[", close: "]") {
            return marker
        }
        if let marker = bracketMarker(in: line, open: "【", close: "】") {
            return marker
        }
        if let marker = colonMarker(in: line) {
            return marker
        }
        return ("旁白", line, true)
    }

    private static func bracketMarker(in line: String, open: Character, close: Character) -> (roleName: String, text: String, wasUnmarked: Bool)? {
        guard line.first == open,
              let closeIndex = line.firstIndex(of: close)
        else {
            return nil
        }

        let roleStart = line.index(after: line.startIndex)
        let roleName = String(line[roleStart..<closeIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let textStart = line.index(after: closeIndex)
        let body = String(line[textStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roleName.isEmpty, !body.isEmpty else { return nil }
        return (roleName, body, false)
    }

    private static func colonMarker(in line: String) -> (roleName: String, text: String, wasUnmarked: Bool)? {
        let separators: [Character] = ["：", ":"]
        guard let separatorIndex = line.firstIndex(where: { separators.contains($0) }) else {
            return nil
        }

        let roleName = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let textStart = line.index(after: separatorIndex)
        let body = String(line[textStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLikelyRoleName(roleName), !body.isEmpty else { return nil }
        return (roleName, body, false)
    }

    private static func isLikelyRoleName(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 12 else { return false }
        let blockedCharacters = CharacterSet(charactersIn: "，。！？!?；;、,. ")
        return value.rangeOfCharacter(from: blockedCharacters) == nil
    }

    static func normalizeRoleName(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "　", with: "")
        return normalized.isEmpty ? "旁白" : normalized
    }
}
