#if !canImport(UIKit) && canImport(AppKit)
    import AppKit
    @testable import GhosttyTerminal
    import Testing

    /// The user-input seam Broadcast Input rides: what the AppKit view reports
    /// as it delivers input, and replaying a report through a surface's own
    /// encoder under that surface's modes.
    @Suite("AppTerminalViewUserInput", .serialized)
    @MainActor
    struct AppTerminalViewUserInputTests {
        @MainActor
        final class Recorder: TerminalSurfaceUserInputDelegate {
            var inputs: [TerminalUserInput] = []
            func terminalDidSendUserInput(_ input: TerminalUserInput) {
                inputs.append(input)
            }
        }

        static let upArrow = Key(code: 126, characters: "\u{F700}", ignoringModifiers: "\u{F700}")

        private func makeRig() -> AppKitInputRig {
            AppKitInputRig(view: ScriptedInputView(frame: NSRect(x: 0, y: 0, width: 800, height: 500)))
        }

        @Test
        func `a typed letter is reported as the key it was`() async {
            let harness = await GhosttySurfaceHarness.make()
            defer { harness.tearDown() }
            let rig = makeRig()
            defer { rig.tearDown() }
            let recorder = Recorder()
            rig.view.delegate = recorder

            rig.press(.letter("a", code: 0))
            #expect(await rig.take() == Data("a".utf8))
            let presses = recorder.inputs.compactMap { input -> TerminalKeyInput? in
                guard case let .key(key) = input, key.action == .press else { return nil }
                return key
            }
            #expect(presses.count == 1)
            #expect(presses.first?.keycode == 0)
            #expect(presses.first?.text == "a")
        }

        @Test
        func `a replayed key is encoded under the receiving modes and never reported`() async {
            let harness = await GhosttySurfaceHarness.make()
            defer { harness.tearDown() }
            let rig = makeRig()
            defer { rig.tearDown() }
            let recorder = Recorder()
            rig.view.delegate = recorder

            rig.press(Self.upArrow)
            #expect(await rig.take().visible == "\\e[A")
            guard let captured = recorder.inputs.first(where: {
                if case let .key(key) = $0 { key.action == .press } else { false }
            }) else {
                Issue.record("the arrow press was not reported")
                return
            }

            // Application cursor-key mode: the same key, re-encoded here.
            rig.receive("\u{1B}[?1h")
            recorder.inputs.removeAll()
            #expect(rig.view.replayUserInput(captured))
            #expect(await rig.take().visible == "\\eOA")
            #expect(recorder.inputs.isEmpty)
        }

        @Test
        func `a replayed paste follows the receiving bracketed-paste mode`() async {
            let harness = await GhosttySurfaceHarness.make()
            defer { harness.tearDown() }
            let rig = makeRig()
            defer { rig.tearDown() }

            #expect(rig.view.replayUserInput(.paste("echo hi")))
            #expect(await rig.take() == Data("echo hi".utf8))
            rig.receive("\u{1B}[?2004h")
            #expect(rig.view.replayUserInput(.paste("echo hi")))
            #expect(await rig.take().visible == "\\e[200~echo hi\\e[201~")
        }

        @Test
        func `host injection is not user input`() async {
            let harness = await GhosttySurfaceHarness.make()
            defer { harness.tearDown() }
            let rig = makeRig()
            defer { rig.tearDown() }
            let recorder = Recorder()
            rig.view.delegate = recorder

            rig.view.paste(text: "x")
            rig.view.sendKey(.enter)
            _ = await rig.take()
            #expect(recorder.inputs.isEmpty)
        }

        @Test
        func `replay needs a surface`() {
            let view = AppTerminalView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            #expect(!view.replayUserInput(.paste("x")))
        }
    }
#endif
