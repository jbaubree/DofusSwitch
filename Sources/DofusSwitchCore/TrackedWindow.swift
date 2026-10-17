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

    /// Removes a trailing " - <digits>..." segment produced by Dofus Unity version suffixes.
    public static func stripVersionSuffix(from title: String) -> String {
        let parts = title.components(separatedBy: " - ")
        guard parts.count >= 2,
              let last = parts.last,
              let first = last.first,
              first.isNumber
        else { return title }
        return parts.dropLast().joined(separator: " - ")
    }

    public static func == (lhs: TrackedWindow, rhs: TrackedWindow) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.pid == rhs.pid
    }
}
