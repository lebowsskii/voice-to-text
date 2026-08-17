import AppKit
import Testing
@testable import VoiceToText

/// The one adapter that is pure logic over a synchronously testable system API
/// — and the one that can destroy the user's data if it gets restore wrong.
///
/// Every test runs against a private pasteboard, never `.general`: these must
/// not touch the clipboard of whoever is running the suite.
@Suite("SystemPasteboard")
struct SystemPasteboardTests {

    /// A private pasteboard, released when the block returns.
    private func withPrivatePasteboard(_ body: (NSPasteboard) throws -> Void) rethrows {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.clearContents()
        try body(board)
    }

    @Test("plain text survives the round trip")
    func plainTextRoundTrip() throws {
        try withPrivatePasteboard { board in
            board.setString("user's original clipboard", forType: .string)
            let sut = SystemPasteboard(pasteboard: board)

            let snapshot = sut.snapshot()
            sut.write("transcribed text")
            #expect(board.string(forType: .string) == "transcribed text")

            sut.restore(snapshot)
            #expect(board.string(forType: .string) == "user's original clipboard")
        }
    }

    @Test("an item carrying several representations keeps all of them")
    func multipleTypesOnOneItem() throws {
        try withPrivatePasteboard { board in
            let rtf = Data("{\\rtf1 hello}".utf8)
            let item = NSPasteboardItem()
            item.setString("hello", forType: .string)
            item.setData(rtf, forType: .rtf)
            board.writeObjects([item])

            let sut = SystemPasteboard(pasteboard: board)
            let snapshot = sut.snapshot()
            sut.write("transcribed text")
            sut.restore(snapshot)

            // Pasting into a rich-text editor must still yield rich text, not
            // the plain-text fallback.
            #expect(board.string(forType: .string) == "hello")
            #expect(board.data(forType: .rtf) == rtf)
        }
    }

    @Test("several text items stay several items, not one run-together blob")
    func multipleTextItemsRoundTrip() throws {
        try withPrivatePasteboard { board in
            board.writeObjects(["alpha", "beta", "gamma"].map { text in
                let item = NSPasteboardItem()
                item.setString(text, forType: .string)
                return item
            })

            let sut = SystemPasteboard(pasteboard: board)
            let snapshot = sut.snapshot()
            sut.write("transcribed text")
            sut.restore(snapshot)

            let restored = (board.pasteboardItems ?? []).compactMap { $0.string(forType: .string) }
            #expect(restored == ["alpha", "beta", "gamma"])
        }
    }

    @Test("a second copied image is not dropped")
    func multipleBinaryItemsRoundTrip() throws {
        try withPrivatePasteboard { board in
            let first = Data(repeating: 1, count: 10)
            let second = Data(repeating: 2, count: 20)
            board.writeObjects([first, second].map { data in
                let item = NSPasteboardItem()
                item.setData(data, forType: .tiff)
                return item
            })

            let sut = SystemPasteboard(pasteboard: board)
            let snapshot = sut.snapshot()
            sut.write("transcribed text")
            sut.restore(snapshot)

            let restored = (board.pasteboardItems ?? []).compactMap { $0.data(forType: .tiff) }
            #expect(restored == [first, second])
        }
    }

    @Test("copying several files in Finder and dictating gives all of them back")
    func multipleFileURLsRoundTrip() throws {
        try withPrivatePasteboard { board in
            let urls = [
                URL(fileURLWithPath: "/tmp/one.txt"),
                URL(fileURLWithPath: "/tmp/two.txt"),
                URL(fileURLWithPath: "/tmp/three.txt")
            ]
            board.writeObjects(urls as [NSURL])

            let sut = SystemPasteboard(pasteboard: board)
            let snapshot = sut.snapshot()
            sut.write("transcribed text")
            sut.restore(snapshot)

            let restored = board.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
            #expect(restored.map(\.path) == urls.map(\.path))
        }
    }

    @Test("an empty clipboard restores as empty rather than keeping the transcription")
    func emptyClipboardRoundTrip() throws {
        try withPrivatePasteboard { board in
            let sut = SystemPasteboard(pasteboard: board)

            let snapshot = sut.snapshot()
            sut.write("transcribed text")
            sut.restore(snapshot)

            #expect(board.string(forType: .string) == nil)
        }
    }
}
