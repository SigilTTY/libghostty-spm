//
//  AppTerminalView+UserInput.swift
//  libghostty-spm
//
//  Both halves of the user-input seam (TerminalUserInput): the view reports
//  what the user is typing or pasting, and delivers input captured on
//  another view as if it had been typed here.
//

#if !canImport(UIKit) && canImport(AppKit)
    import AppKit

    /// User-input reporting state; behavior lives in +UserInput.
    struct UserInputReportState {
        /// Set while a paste chord's key event runs through `keyDown`: the
        /// chord is reported as the paste it performs, not as a key too.
        var suppressed = false
    }

    public extension AppTerminalView {
        /// Delivers input captured on another surface
        /// (``TerminalSurfaceUserInputDelegate``) as if the user had typed it
        /// here: key events through this surface's encoder and terminal
        /// modes, text and pastes through its paste pipeline. Never reported
        /// back, so a replay cannot echo. False — delivering nothing — when
        /// the view has no surface yet (it was never on screen).
        @discardableResult
        func replayUserInput(_ input: TerminalUserInput) -> Bool {
            core.replay(input)
        }
    }

    extension AppTerminalView {
        /// Whether anyone listens — lets the paste paths skip a pasteboard
        /// read for hosts that never adopted the seam.
        var reportsUserInput: Bool {
            delegate is any TerminalSurfaceUserInputDelegate
        }

        /// Called by the view's own input paths only, right before the input
        /// reaches the surface.
        func reportUserInput(_ input: TerminalUserInput) {
            guard !userInputReports.suppressed else { return }
            (delegate as? any TerminalSurfaceUserInputDelegate)?
                .terminalDidSendUserInput(input)
        }
    }
#endif
