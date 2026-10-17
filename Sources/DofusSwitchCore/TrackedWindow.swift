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

    public var normalizedKey: String {
        Self.normalizedKey(from: title)
    }

    public static func normalizedKey(from title: String) -> String {
        let lowered = title.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed
    }

    public static func == (lhs: TrackedWindow, rhs: TrackedWindow) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.pid == rhs.pid
    }
}
