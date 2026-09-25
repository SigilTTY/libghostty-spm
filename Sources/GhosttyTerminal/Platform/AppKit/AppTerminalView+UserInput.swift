//
//  AppTerminalView+UserInput.swift
//  libghostty-spm
//
//  Both halves of the user-input seam (TerminalUserInput): the view reports
//  what the user is typing or pasting, and delivers input captured on
//  another view as if it had been typed here.
//

#if canImport(AppKit) && !canImport(UIKit)
    import AppKit

    extension AppTerminalView {
        /// Delivers input captured on another surface
        /// (``TerminalSurfaceUserInputDelegate``) as if the user had typed
        /// it here: key events go through THIS surface's encoder and terminal
        /// modes, text and pastes through its paste pipeline, bytes straight
        /// to the in-memory backend. Never reported back to the delegate, so
        /// a replay cannot echo. Returns false — and delivers nothing — when
        /// the view has no surface yet (it was never on screen).
        @discardableResult
        public func replayUserInput(_ input: TerminalUserInput) -> Bool {
            core.replay(input)
        }

        /// Whether anyone listens — lets the paste paths skip a pasteboard
        /// read for hosts that never adopted the seam.
        var reportsUserInput: Bool {
            delegate is any TerminalSurfaceUserInputDelegate
        }

        /// Called by the view's own input paths only, right before the input
        /// reaches the surface.
        func reportUserInput(_ input: TerminalUserInput) {
            guard !suppressesUserInputReports else { return }
            (delegate as? any TerminalSurfaceUserInputDelegate)?
                .terminalDidSendUserInput(input)
        }
    }
#endif
