import Foundation

/// Puts text where the user's cursor is.
protocol TextInserter {
    func insert(_ text: String) throws
    /// Restores whatever the inserter is holding onto (clipboard contents)
    /// without waiting for its own timer.
    func flushPendingRestore()
}
