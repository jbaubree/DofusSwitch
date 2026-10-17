import Foundation

public final class CycleController {
    private var currentKey: String?

    public init() {}

    public func next(in windows: [TrackedWindow]) -> TrackedWindow? {
        pickAndMark(in: windows, offset: 1)
    }

    public func prev(in windows: [TrackedWindow]) -> TrackedWindow? {
        pickAndMark(in: windows, offset: -1)
    }

    public func currentIndex(in windows: [TrackedWindow]) -> Int? {
        guard let key = currentKey else { return nil }
        return windows.firstIndex(where: { $0.normalizedKey == key })
    }

    private func pickAndMark(in windows: [TrackedWindow], offset: Int) -> TrackedWindow? {
        guard !windows.isEmpty else { return nil }
        let target: TrackedWindow?
        if let key = currentKey,
           let idx = windows.firstIndex(where: { $0.normalizedKey == key }) {
            let n = windows.count
            let next = ((idx + offset) % n + n) % n
            target = windows[next]
        } else {
            target = offset >= 0 ? windows.first : windows.last
        }
        currentKey = target?.normalizedKey
        return target
    }
}
