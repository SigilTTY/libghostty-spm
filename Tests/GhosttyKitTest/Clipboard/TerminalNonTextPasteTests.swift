#if !canImport(UIKit) && canImport(AppKit)
    import AppKit
    import Foundation
    @testable import GhosttyTerminal
    import Testing

    /// Which pasteboards a paste gesture offers to the host before pasting
    /// itself. The pasteboards are the tests' own, never the general one.
    @Suite("TerminalNonTextPaste")
    @MainActor
    struct TerminalNonTextPasteTests {
        private func withPasteboard(_ body: (NSPasteboard) -> Void) {
            let pasteboard = NSPasteboard(name: .init("ghostty-non-text-paste-test-\(UUID().uuidString)"))
            defer { pasteboard.releaseGlobally() }
            pasteboard.clearContents()
            body(pasteboard)
        }

        @Test
        func `text stays the library's`() {
            withPasteboard { pasteboard in
                pasteboard.setString("ls -la", forType: .string)
                #expect(!TerminalNonTextPaste.pasteboardPrefersHost(pasteboard))
            }
        }

        @Test
        func `a file copy goes to the host even though it carries a name`() {
            withPasteboard { pasteboard in
                pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/shot.png") as NSURL])
                pasteboard.setString("shot.png", forType: .string)
                #expect(TerminalNonTextPaste.pasteboardPrefersHost(pasteboard))
            }
        }

        @Test
        func `image data with no string goes to the host`() {
            withPasteboard { pasteboard in
                pasteboard.setData(Data([0x89, 0x50, 0x4E, 0x47]), forType: .png)
                #expect(TerminalNonTextPaste.pasteboardPrefersHost(pasteboard))
            }
        }

        @Test
        func `an empty string goes to the host`() {
            withPasteboard { pasteboard in
                pasteboard.setString("", forType: .string)
                #expect(TerminalNonTextPaste.pasteboardPrefersHost(pasteboard))
            }
        }

        @Test
        func `only a plain command V is the paste chord`() throws {
            func event(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
                try #require(NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                    windowNumber: 0, context: nil, characters: "v",
                    charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9,
                ))
            }
            #expect(try TerminalNonTextPaste.isPlainPasteChord(event(.command)))
            #expect(try !TerminalNonTextPaste.isPlainPasteChord(event([.command, .shift])))
            #expect(try !TerminalNonTextPaste.isPlainPasteChord(event([.command, .option])))
            #expect(try !TerminalNonTextPaste.isPlainPasteChord(event([])))
        }
    }
#endif
