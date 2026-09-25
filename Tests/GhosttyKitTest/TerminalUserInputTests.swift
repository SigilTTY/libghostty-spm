import Foundation
import GhosttyKit
@testable import GhosttyTerminal
import Testing

struct TerminalUserInputTests {
    @Test
    func `key input survives a round trip through the C event`() {
        let key = TerminalKeyInput(
            action: .repeated,
            keycode: 0x00,
            modifiers: [.shift, .alt],
            consumedModifiers: [.shift],
            text: "Å",
            unshiftedCodepoint: 0x61,
            composing: true
        )

        let (copy, borrowedText) = key.withGhosttyEvent { event in
            (TerminalKeyInput(event, text: key.text), event.text.map { String(cString: $0) })
        }

        #expect(copy == key)
        #expect(borrowedText == "Å")
    }

    @Test
    func `key input without text carries a null text pointer`() {
        let key = TerminalKeyInput(action: .release, keycode: 0x24)

        let isNull = key.withGhosttyEvent { $0.text == nil }

        #expect(isNull)
    }

    @Test
    func `actions map onto ghostty's action values`() {
        let actions: [TerminalKeyInput.Action] = [.press, .release, .repeated]
        let expected = [GHOSTTY_ACTION_PRESS, GHOSTTY_ACTION_RELEASE, GHOSTTY_ACTION_REPEAT]

        for (action, raw) in zip(actions, expected) {
            let key = TerminalKeyInput(action: action, keycode: 0)
            let (mapped, back) = key.withGhosttyEvent { event in
                (event.action, TerminalKeyInput(event, text: nil).action)
            }
            #expect(mapped == raw)
            #expect(back == action)
        }
    }

    #if canImport(AppKit) && !canImport(UIKit)
        @Test
        @MainActor
        func `replay delivers nothing before the view has a surface`() {
            let written = WriteLog()
            let session = InMemoryTerminalSession(write: { written.append($0) }, resize: { _ in })
            let view = AppTerminalView(frame: .zero)
            view.configuration = TerminalSurfaceOptions(backend: .inMemory(session))

            #expect(!view.replayUserInput(.key(TerminalKeyInput(action: .press, keycode: 0x00, text: "a"))))
            #expect(!view.replayUserInput(.bytes(Data([0x7F]))))
            #expect(!view.replayUserInput(.text("ä")))
            #expect(!view.replayUserInput(.paste("ls\n")))
            #expect(written.isEmpty)
        }
    #endif
}

private final class WriteLog: @unchecked Sendable {
    private let lock = NSLock()
    private var chunks: [Data] = []

    func append(_ data: Data) {
        lock.lock()
        chunks.append(data)
        lock.unlock()
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return chunks.isEmpty
    }
}
