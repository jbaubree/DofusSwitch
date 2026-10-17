import Foundation

public struct TrackedWindow: Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let pid: pid_t
    public let axElementRef: AnyObject?   // AXUIElement; opaque at this layer

    public init(id: UUID = UUID(), title: String, pid: pid_t, axElementRef: AnyObject? = nil) {
        self.id = id
        self.title = title
        self.pid = pid
        self.axElementRef = axElementRef
    }

    /// Title with any trailing version segment stripped (e.g. "Myrdak - Iop - 3.7.11.6" → "Myrdak - Iop").
    public var displayTitle: String {
        Self.stripVersionSuffix(from: title)
    }

    public var normalizedKey: String {
        Self.normalizedKey(from: displayTitle)
    }

    public static func normalizedKey(from title: String) -> String {
        let lowered = title.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed
    }

    /// Strips Dofus Unity's trailing version and build-type segments.
    /// e.g. "Minak - Sacrieur - 3.7.11.11 - Release" → "Minak - Sacrieur".
    /// Repeatedly drops the last `" - "`-separated segment while it starts with a
    /// digit (version) or matches a known build-type keyword (release/debug/beta/…).
    public static func stripVersionSuffix(from title: String) -> String {
        let buildKeywords: Set<String> = ["release", "debug", "beta", "development", "staging", "preview"]
        var parts = title.components(separatedBy: " - ")
        while parts.count > 1, let last = parts.last {
            if let first = last.first, first.isNumber {
                parts.removeLast()
                continue
            }
            let normalized = last.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if buildKeywords.contains(normalized) {
                parts.removeLast()
                continue
            }
            break
        }
        return parts.joined(separator: " - ")
    }

    public static func == (lhs: TrackedWindow, rhs: TrackedWindow) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.pid == rhs.pid
    }
}
