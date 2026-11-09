//
//  TerminalSurfaceCoordinator+UserInput.swift
//  libghostty-spm
//

import Foundation

extension TerminalSurfaceCoordinator {
    /// Delivers input captured on another surface as if it had been typed
    /// here: key events through this surface's own encoder, text and pastes
    /// through its paste pipeline. False, delivering nothing, with no surface.
    func replay(_ input: TerminalUserInput) -> Bool {
        guard let surface else { return false }
        switch input {
        case let .key(key):
            _ = key.withGhosttyEvent { event in
                surface.sendKeyEvent(event)
            }
        case let .text(text), let .paste(text):
            _ = surface.paste(text: text)
        }
        return true
    }
}
